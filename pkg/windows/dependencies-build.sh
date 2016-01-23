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

setups=($(ls -1 ${source_ro_path}/pkg/windows | grep '.nis$' | sed 's|.nis$||'))
# add mingw dlls that are build in other steps
function addMingwDlls() {
  root=$1
  cp /usr/lib/gcc/i686-w64-mingw32/4.9-win32/libgcc_s_sjlj-1.dll ${root}
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
  popd
}
# create installable binaries with dlls
function createInstallables() {
  rm -r ${absolute_executable_path}
  mkdir -p ${absolute_executable_path}
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
      --paths=C:\\python27\\lib\\site-packages\\ \
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
# generate nsis file references for installer for single directory
# appends File and Remove to files that are later included by makensis
# separate files for install and uninstall statements
#
# directory_root: the tree root that is currently generated
# subdir: any directory in the tree
# setup_name: the name of the setup this nsh entries are generated for
function generateDirectoryNSISStatements() {
  directory_root=$1
  subdir=$2
  setup_name=$3
  find ${subdir} -maxdepth 1 -type f -exec echo 'File "'${relative_executable_path}'/{}"' \;>> ${setup_name}_install_files.nsh
  find ${subdir} -maxdepth 1 -type f -exec echo 'Delete "$INSTDIR/{}"' \;  >> ${setup_name}_uninstall_files.nsh
}
# generate a tree of files into nsis installer definitions
# directory_root: the tree root that is currently generated
# setup_name: the name of the setup this nsh entries are generated for
function generateDirectoryNSISStatementsTree() {
  directory_root=$1
  setup_name=$2
  subdirs=$(find ${directory_root} -type d | sort)
  for subdir in ${subdirs[@]}
  do
    if [ "${directory_root}" != "${subdir}" ]; then
      echo 'SetOutPath "$INSTDIR/'${subdir}'"' >> ${setup_name}_install_files.nsh
    fi
    generateDirectoryNSISStatements ${directory_root} ${subdir} ${setup_name}
  done
  # again to remove emptied directories on uninstall so reverse
  subdirs=$(find ${directory_root} -type d | sort | tac)
  for subdir in ${subdirs[@]}
  do
    if [ "${directory_root}" != "${subdir}" ]; then
      echo 'RMDir "$INSTDIR/'${subdir}'"' >> ${setup_name}_uninstall_files.nsh
    fi
  done
}
# generate installer files for the available setups
# those files include install and uninstall statements and are
# modified (backslashes/source_path) to generate a sane target
# structure
function generateNSISStatements() {
  pushd ${absolute_executable_path}
  for setup in "${setups[@]}"
  do
    echo "setup:" ${setup}
    echo "# auto generated by pkg/windows/dependencies-build.sh please do not modify" > ${setup}_install_files.nsh
    echo "# auto generated by pkg/windows/dependencies-build.sh please do not modify" > ${setup}_uninstall_files.nsh
    setup_source_path=${setup}
    generateDirectoryNSISStatementsTree ${setup_source_path} ${setup}
    # remove the setup_source_path from the nsh files
    sed -i "s|INSTDIR/${setup_source_path}/|INSTDIR/|" ${setup}_install_files.nsh
    sed -i "s|/${setup_source_path}/|/|" ${setup}_uninstall_files.nsh
    # make backslashes
    sed -i "s|/|\\\\|g" ${setup}_install_files.nsh ${setup}_uninstall_files.nsh
    # make install size
    installed_size=$(du -s --block-size=1000 ${setup} | awk '{print $1}')
    echo "!define INSTALLSIZE ${installed_size}" > ${setup}_install_files_size.nsh
  done
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
  # execute qt-uic / qt-rcc
  wine mingw32-make all

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
  # migrate to requirements?
  wine pip install dateutils simplejson jsonschema pycryptopp routes paste chardet scrypt gnupg
  # u1db - broken by dirspec
  curl https://pypi.python.org/packages/source/u/u1db/u1db-0.1.4.tar.bz2 > u1db-0.1.4.tar.bz2
  curl https://pypi.python.org/packages/source/p/pysqlcipher/pysqlcipher-2.6.4.tar.gz > pysqlcipher-2.6.4.tar.gz
  tar xjf u1db-0.1.4.tar.bz2
  pushd u1db-0.1.4
  patch -p0 < ${source_ro_path}/pkg/windows/dependencies/u1db_setup.py.patch
  patch -p0 < ${source_ro_path}/pkg/windows/dependencies/u1db_cosas_cosas.py.patch
  wine python setup.py build install
  popd
  tar xzf pysqlcipher-2.6.4.tar.gz
  pushd pysqlcipher-2.6.4
  curl https://downloads.leap.se/libs/pysqlcipher/amalgamation-sqlcipher-2.1.0.zip > amalgamation-sqlcipher-2.1.0.zip
  unzip amalgamation-sqlcipher-2.1.0.zip
  mv sqlcipher amalgamation
  patch -p0 < ${source_ro_path}/pkg/windows/dependencies/pysqlcipher_setup.py.patch
  wine python setup.py build install
  popd
  # unpack egg that is not found by pyinstaller otherwise
  pushd /root/.wine/dosdevices/c:/Python27/Lib/site-packages
  unzip -o pysqlcipher-2.6.4-py2.7-win32.egg
  popd
}
# prepare read-write copy
function prepareBuildPath() {
  cleanup
  git clone ${source_ro_path} ${temporary_build_path}
  pushd ${temporary_build_path}
  git checkout 0.9.1
  popd
  # while this branch is not merged and not in a tag we need to do this
  # in order to get the correct spec-files
  rm ${temporary_build_path}/pkg/pyinst/*
  cp ${source_ro_path}/pkg/pyinst/* ${temporary_build_path}/pkg/pyinst
  cp -rf /var/build/leap.bitmask-0.9.1-SUMO/src/* ${temporary_build_path}/src
  # hack the logger
  sed -i "s|'bitmask.log'|str(random.random()) + '_bitmask.log'|;s|import sys|import sys\nimport random|" ${temporary_build_path}/src/leap/bitmask/logs/utils.py
  sed -i "s|perform_rollover=True|perform_rollover=False|" ${temporary_build_path}/src/leap/bitmask/app.py
  # patch the merge request
  curl https://raw.githubusercontent.com/PaixuAabuizia/leap_pycommon/5339b551cdfd32dfd3c61abd2ab006a05a86358b/src/leap/common/config/__init__.py \
    > ${temporary_build_path}/src/leap/common/config/__init__.py
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
  installProjectDependencies
  installProjectDependenciesBroken
  createInstallablesDependencies
  createInstallables
  generateNSISStatements
  cleanup
}
main $@