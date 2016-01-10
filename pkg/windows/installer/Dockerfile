FROM debian:jessie
MAINTAINER me@log0.de
RUN apt-get update


######
# install packages required to build

RUN apt-get -y install \
    python nsis \
    python-setuptools python-pip \
 && pip install pyinstaller
WORKDIR /var/src/bitmask/pkg/windows
RUN useradd installer
USER installer
ENTRYPOINT ["/var/src/bitmask/pkg/windows/installer-build.sh"]