Environment setup in debian:jessie
==================================

basically you need this to setup your environment:

# apt-get install mingw-w64
# apt-get install wine
# apt-get install nsis

this is a incomplete list of dependencies, review the dependencies/Dockerfile
to get a understanding of what needs to be setup in order to have a
environment that builds the installer

Requirements
============
none

Building the package
====================

make pkg

Building the binaries
---------------------

make binaries

you need to build the technical dependencies to package a installer
suitable for windows users. those include
* openvpn
** lzo
** opensc
** openssl
* python

Reproducible builds
===================

please run the binary and installer builds on a clean machine eg
using docker or any virtual environment that can easily be prepared
by a third party to verify that the binaries are actually what the
sourcecode suggests.

to use reproducible build you need to install docker which then installs
a clean debian:jessie to install nsis or the mingw environment


Installer
=========

NSIS was choosen because it provided a out of the box toolchain to build
installers for the windows platform with minimal dependencies. The downside
of nsis is that it does not produce msi binaries

to build the binary dependencies run:

```
docker-compose run --rm dependencies
```

the produced binaries will be stored in ${ROOT}/build

to build the installer run:

```
docker-compose run --rm installer
```

the produced installer will be stored in ${ROOT}/dist


Dependencies
============

Dependencies is a docker image based on debian:jessie with a cross-compile
toolchain (gcc) for building zlib and openssl in linux and wine (staging)
with installed python and mingw32 for pip/wheel compiling.
The hard dependencies (zlib/openssl) are part of the image as their content
is not under development in this project. All pip installed dependencies are
part of the dependency-build.sh script so they can be re-executed when the
dependencies of the project change. The image should be rebuild when openssl,
python or pyinstaller is updated:

```
docker-compose build dependencies
```

This image may be used to build other python projects as well, as openssl and
zlib is a common dependency for todays software.

To debug or fine-tune the compile process it may be useful to setup the
following software on the development machine:

```
X :1 -listen tcp
DISPLAY=:1 xhost +
docker-compose run --rm dependencies /bin/bash
root@0fa19215321f:/# export DISPLAY=${YOUR_LOCAL_IP}:1
root@0fa19215321f:/# wine cmd
Z:\>python
>>>
```

the configured volumes are:

- the (read-only) sourcecode of the bitmask project in /var/src/bitmask
- the result of the builds in /var/build

dependency-build.sh
===================

Contains all steps to build the win32 executables. The project relies on
a read-write source tree which will pollute the development environment and
make it hard to reproduce 'clean' builds. therefore it expects that the source
is freshly checked out and not used to run in the host-environment. Otherwise
pyc and ui elements will mess up the binary in unpredictable ways.

* copy the /var/src/bitmask sources to a read-write location (/var/build)
* execute ```make all``` in wine to build the qt ui and other resources
* execute ```pip install $dependencies``` to have all dependencies available
* execute ```pyinstaller``` in wine to compile the executable for
** bitmask (src/leap/bitmask/app.py)
** bitmask_frontend (src/leap/bitmask/frontend_app.py)
** bitmask_backend (src/leap/bitmask/backend_app.py)
* cleanup
** remove the read-write copy
** remove wine-dlls from the installer

As the step 'install dependencies' may take long on slow internet connections
during development it is advised to recycle the container:

```
docker-compose run --rm dependencies /bin/bash
root@0fa19215321f:/# cd /var/src/bitmask/pkg/windows
root@0fa19215321f:/var/src/bitmask/pkg/windows# ./dependencies-build.sh
root@0fa19215321f:/var/src/bitmask/pkg/windows# ./dependencies-build.sh
root@0fa19215321f:/var/src/bitmask/pkg/windows# ./dependencies-build.sh
....
```

and test the result binary (accessible in bitmask/build in a separate vm.
