#!/bin/bash

# build installer
# ===============
#
# builds several installers from previously compiled binaries

cd /var/src/bitmask/pkg/windows/
for install_script in *.nis
do
makensis ${install_script}
done