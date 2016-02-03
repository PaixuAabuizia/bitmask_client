#!/bin/bash

# render dependencies into separate subdirectories
# ================================================
#
# requires
#  - a linux host with wine, wine with python and mingw installed
#  - the sourcecode mounted to /var/src/
#  - a rw directory mounted to /var/build
#  returns nonzero exit code when pyinstaller failed
#
# prepares a read-write copy of the sourcecode
# executes qt-uic and qt-rcc for gui dialogs
# installs dependencies from pkg/dependencies-windows.pip
# runs pyinstaller
# cleans up (remove wine-dlls, remove read-write copy)
# creates nsis install/uninstall scripts for the files for each package


product=bitmask
# the location where the pyinstaller results are placed
absolute_executable_path=/var/build/executables
# the location of the nsis installer nis files dictates the path of the files
relative_executable_path=../../build/executables
source_ro_path=/var/src/${product}
temporary_build_path=/var/build/${product}_rw
git_tag=HEAD
export WINEDEBUG=fixme-all

setups=($(ls -1 ${source_ro_path}/pkg/windows | grep '.nis$' | sed 's|.nis$||'))
# add mingw dlls that are build in other steps
function addMingwDlls() {
  root=$1
  cp /usr/lib/gcc/i686-w64-mingw32/4.9-win32/libgcc_s_sjlj-1.dll ${root}
  cp /root/.wine/drive_c/Python27/Lib/site-packages/zmq/libzmq.pyd ${root}
  cp /root/.wine/drive_c/Python27/Lib/site-packages/zmq/libzmq.pyd ${root}
  mkdir -p ${root}/pysqlcipher
  cp /var/build/bitmask_rw/pkg/pyinst/build/bitmask/pysqlcipher-2.6.4-py2.7-win32.egg/pysqlcipher/_sqlite.pyd ${root}/pysqlcipher
  cp ~/.wine/dosdevices/c:/openssl/bin/*.dll ${root}
}
# cleanup the temporary build path for subsequent executes
function cleanup() {
  rm -r ${temporary_build_path} 2>/dev/null
}
# create files that are not part of the repository but are needed
# in the windows environment:
# - license with \r\n
# - ico from png (multiple sizes for best results on high-res displays)
function createInstallablesDependencies() {
  pushd ${temporary_build_path} > /dev/null
  cat LICENSE | sed 's|\n|\r\n|g' > LICENSE.txt
  convert data/images/mask-icon.png  -filter Cubic -scale 256x256! data/images/mask-icon-256.png
  convert data/images/mask-icon-256.png -define icon:auto-resize data/images/mask-icon.ico
  # execute qt-uic / qt-rcc
  wine mingw32-make all
  popd
}
# create installable binaries with dlls
function createInstallables() {
  rm -r ${absolute_executable_path}
  mkdir -p ${absolute_executable_path}

  # namespace in site-packages leads to unresolvable local src/leap namespace
  # they need to get installed with pip, but must not be available for pyinstaller
  mkdir -p /root/.wine/drive_c/Python27/Lib/site-packages/leap_masked_root
  mv /root/.wine/drive_c/Python27/Lib/site-packages/leap /root/.wine/drive_c/Python27/Lib/site-packages/masked_leap 2>/dev/null
  mv /root/.wine/drive_c/Python27/Lib/site-packages/leap* /root/.wine/drive_c/Python27/Lib/site-packages/masked_leap_root 2>/dev/null
  cp -r /root/.wine/drive_c/Python27/Lib/site-packages/masked_leap/* ${temporary_build_path}/src/leap
  cp -r /root/.wine/drive_c/Python27/Lib/site-packages/masked_leap_root/* ${temporary_build_path}/src
  # rm ${temporary_build_path}/src/*.pth

  pushd ${temporary_build_path}/pkg/pyinst
  # build install directories (contains multiple files with pyd,dll, some of
  # them look like windows WS_32.dll but are from wine)
  for setup in ${setups[@]}
  do
    # --clean do not cache anything and overwrite everything --noconfirm
    # --distpath to place on correct location
    # --debug to see what may be wrong with the result
    # --paths=c:\python\lib\site-packages;c:\python27\lib\site-packages
    wine pyinstaller \
      --clean \
      --noconfirm \
      --distpath=.\\installables \
      --paths=Z:\\var\\build\\bitmask_rw\\src\\ \
      --paths=C:\\Python27\\Lib\\site-packages\\ \
      --debug \
      ${setup}.spec \
    || exit 1
    removeWineDlls installables/${setup}
    addMingwDlls installables/${setup}
    cp -r installables/${setup} ${absolute_executable_path}
    rm -r installables
  done
  popd
  pushd ${temporary_build_path}
  cp data/images/mask-icon.ico ${absolute_executable_path}/
  cp LICENSE.txt ${absolute_executable_path}/
  popd
}

# install (windows)dependencies of project
function installProjectDependencies() {
  pushd ${temporary_build_path} > /dev/null
  unsupported_packages="dirspec"
  pip_flags="--find-links=Z:${temporary_build_path}/wheels"
  for unsupported_package in ${unsupported_packages}
  do
    pip_flags="${pip_flags} --allow-external ${unsupported_package} --allow-unverified ${unsupported_package}"
  done
  pip_flags="${pip_flags} -r"

  # install dependencies
  mkdir -p ${temporary_build_path}/wheels
  wine pip install ${pip_flags} pkg/requirements-leap.pip
  # fix requirements
  # python-daemon breaks windows build
  sed -i 's|^python-daemon|#python-daemon|' pkg/requirements.pip
  wine pip install ${pip_flags} pkg/requirements.pip
  popd
}
function installProjectDependenciesBroken() {
  pushd ${temporary_build_path} > /dev/null
  curl https://pypi.python.org/packages/source/p/pysqlcipher/pysqlcipher-2.6.4.tar.gz > pysqlcipher-2.6.4.tar.gz
  tar xzf pysqlcipher-2.6.4.tar.gz
  pushd pysqlcipher-2.6.4
  curl https://downloads.leap.se/libs/pysqlcipher/amalgamation-sqlcipher-2.1.0.zip > amalgamation-sqlcipher-2.1.0.zip
  unzip -o amalgamation-sqlcipher-2.1.0.zip
  mv sqlcipher amalgamation
  patch -p0 < ${source_ro_path}/pkg/windows/dependencies/pysqlcipher_setup.py.patch
  wine python setup.py build install
  popd
  popd # temporary_build_path
}
# prepare read-write copy
function prepareBuildPath() {
  cleanup
  if [ ${git_tag} != "HEAD" ]; then
    echo "using ${git_tag} as source for the project"
    git clone ${source_ro_path} ${temporary_build_path}
    pushd ${temporary_build_path}
    git checkout ${git_tag}
    popd
  else
    echo "using current source tree for build"
    mkdir -p ${temporary_build_path}/data
    mkdir -p ${temporary_build_path}/pkg
    mkdir -p ${temporary_build_path}/src
    cp -r ${source_ro_path}/data/* ${temporary_build_path}/data
    cp -r ${source_ro_path}/pkg/* ${temporary_build_path}/pkg
    cp -r ${source_ro_path}/src/* ${temporary_build_path}/src
    cp -r ${source_ro_path}/LICENSE ${temporary_build_path}/
    cp -r ${source_ro_path}/Makefile ${temporary_build_path}/
  fi

  # hack the logger
  sed -i "s|'bitmask.log'|str(random.random()) + '_bitmask.log'|;s|import sys|import sys\nimport random|" ${temporary_build_path}/src/leap/bitmask/logs/utils.py
  sed -i "s|perform_rollover=True|perform_rollover=False|" ${temporary_build_path}/src/leap/bitmask/app.py
  # patch the merge request
}
# remove wine dlls that should not be in the installer
# root: path that should be cleaned from dlls
function removeWineDlls() {
  root=$1
  declare -a wine_dlls=(\
    advapi32.dll \
    comctl32.dll \
    comdlg32.dll \
    gdi32.dll \
    imm32.dll \
    iphlpapi.dll \
    ktmw32.dll \
    msvcp90.dll \
    msvcrt.dll \
    mswsock.dll \
    mpr.dll \
    netapi32.dll \
    ole32.dll \
    oleaut32.dll \
    opengl32.dll \
    psapi.dll \
    rpcrt4.dll \
    shell32.dll \
    user32.dll \
    version.dll \
    winmm.dll \
    winspool.drv \
    ws2_32.dll \
    wtsapi32.dll \
    )
  for wine_dll in "${wine_dlls[@]}"
  do
    # not all of the listed dlls are in all directories
    rm ${root}/${wine_dll} 2>/dev/null
  done
}
function main() {
  prepareBuildPath
  installProjectDependenciesBroken
  installProjectDependencies
  createInstallablesDependencies
  createInstallables
  cleanup
}
main $@