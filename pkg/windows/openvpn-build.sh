#!/bin/bash

# render openvpn prepared for installer
# ================================================
#
# requires
#  - a linux host with mingw installed
#  - a rw directory mounted to /var/build
#  returns nonzero exit code when failed
#
# clone openvpn-build repository
# runs cross-compile build
# - downloads openvpn dependencies
# - compiles
# copy files to executables so they can be installed
# cleans up (remove read-write copy)

product=openvpn
# the location where the pyinstaller results are placed
absolute_executable_path=/var/build/executables
source_ro_path=/var/src/${product}
temporary_build_path=/var/build/${product}_rw

git_tag=HEAD

setups=($(ls -1 ${source_ro_path}/pkg/windows | grep '.nis$' | sed 's|.nis$||'))
# cleanup the temporary build path for subsequent executes
function cleanup() {
  rm -r ${temporary_build_path} 2>/dev/null
}
function buildSource() {
  pushd ${temporary_build_path}/openvpn-build/generic
  CHOST=i686-w64-mingw32 \
  CBUILD=i686-pc-linux-gnu \
  ./build \
  || exit 1
  && cp -r image/openvpn ${absolute_executable_path}/openvpn \
  && cp -r sources/tap-windows* ${absolute_executable_path}/openvpn \
  popd
}
# prepare read-write copy
function prepareBuildPath() {
  cleanup
  pushd ${temporary_build_path}
  git clone https://github.com/OpenVPN/openvpn-build
  popd
}
function main() {
  prepareBuildPath
  buildSource
  cleanup
}
main $@