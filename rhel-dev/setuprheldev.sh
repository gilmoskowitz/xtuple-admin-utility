#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.
WORKDIR=$(pwd)

# What version do you want to build?
# Check: https://github.com/xtuple/qt-client/tags
GITTAG=v4.10.0

installEnv() {
# TODO: Find the actual package names that the distributions use.
# RHEL/Centos, SuSE, Ubuntu

# statisfies all of xtuple requirements and most QT Configure options.
PKG_CMD="yum -y install "
#PKG_CMD="dnf install "

# TODO: Find which linux we're running on and their proper way to
# install packages. lsb_release, /etc/redhat-release, yum, apt, zypper

#if [[ -z IS_SUSE ]]; then
#PKG_CMD=$(zypper -n install)
#fi

${PKG_CMD} axel bison curl deltarpm flex gcc-c++ git gperf nano perl \
    python ruby screen wget yum-utils


${PKG_CMD} alsa-lib alsa-lib-devel cups-devel cups-libs fontconfig-devel \
    gstreamer-devel gstreamer-plugins-base gstreamer-plugins-base-devel \
    gtk2-devel icu krb5-devel libdrm-devel libepoxy libevdev-devel \
    libevdev-utils libfontenc libicu libxcb libxcb-devel \
    libXcomposite-devel libXcomposite-devel libXcursor-devel \
    libXdamage-devel libXdmcp libXfont libxkbfile libxml2-devel \
    libXrandr-devel libXrender-devel libxslt-devel libXtst-devel \
    mariadb-devel mtdev openldap-devel openssl-devel pam-devel perl-devel \
    postgresql-devel postgresql-libs pulseaudio-libs-devel readline \
    readline readline-devel sqlite-devel systemd-devel systemd-libs \
    unixODBC-devel xcb-util xkeyboard-config xkeyboard-config \
    xorg-x11-drv-evdev xorg-x11-drv-evdev-devel xorg-x11-server-common \
    xorg-x11-server-devel xorg-x11-server-Xorg xorg-x11-xkb-utils \
    zlib-devel

}

build_QT() {
# TODO: Check for things already downloaded/configured.

SRCDIR=/usr/local/src

cd $SRCDIR

# wget https://download.qt.io/archive/qt/5.5/5.5.1/single/qt-everywhere-opensource-src-5.5.1.tar.gz
wget https://download.qt.io/archive/qt/5.7/5.7.1/single/qt-everywhere-opensource-src-7.7.1.tar.gz
tar zxvf qt-everywhere-opensource-src-5.7.1.tar.gz


QTSRCDIR=${SRCDIR}/qt-everywhere-opensource-src-5.7.1

# Need to remove leveldb dir in order to build qt-web etc...
# See: https://github.com/xtuple/qt-client/wiki/Desktop-Development-Environment-Setup#get-qt
# https://bugreports.qt.io/browse/QTBUG-15344

rm -r ${QTSRCDIR}/qtwebkit/Tools/qmake/config.tests/leveldb

cd ${QTSRCDIR}

# TODO: These may not be 100% necessary depending on what we are targeting
# i.e. qt-xcb

./configure -qt-sql-psql -qt-sql-sqlite -qt-zlib -qt-libpng -qt-libjpeg \
    -qt-xcb -nomake examples -skip qtwebengine -opensource -confirm-license

make -j$(nproc)

make install

# TODO: Figure out the best cross distro place for this
# Maybe this should be in the global profile?
# ubuntu uses .profile, rhel uses .bash_profile by default.

bash -c "echo export PATH=/usr/local/Qt-5.7.1/bin:$PATH >> ~/.bash_profile"
bash -c "echo export LD_LIBRARY_PATH=/usr/local/Qt-5.7.1/lib:$LD_LIBRARY_PATH >> ~/.bash_profile"

}

build_xtuple() {

# TODO: Set a workdate on each run or a git commit?
WORKDATE=$(date +'%m%d%Y-%s')

XTWORKDIR=${WORKDIR}/xtuple-${WORKDATE}

mkdir -p ${XTWORKDIR}

cd ${XTWORKDIR}

git clone https://github.com/xtuple/qt-client
cd ${XTWORKDIR}/qt-client

# We need to read in our bash_profile to find qmake
source ~/.bash_profile
export LD_LIBRARY_PATH=${XTWORKDIR}/qt-client/openrpt/lib:${XTWORKDIR}/qt-client/lib

if [ -z "$GITTAG" ] ; then

    GITTAG=$(curl https://api.github.com/repos/xtuple/qt-client | \
            awk -v FS='"' '/default_branch/ { print $4 }')

	if [ -z "$GITTAG" ] ; then
    GITTAG=master
    fi

fi

git checkout $GITTAG
git submodule update --init --recursive

cd openrpt
qmake
make -j$(nproc)

cd ../csvimp
qmake
make -j$(nproc)

cd ..
qmake
make -j$(nproc)

}

makePackage() {
#TODO: Make a correct package.
#TODO: Make an RPM
#TODO: Assign a maintainer.
# https://docs.fedoraproject.org/en-US/Fedora_Draft_Documentation/0.1/html/Packagers_Guide/
# https://docs.fedoraproject.org/en-US/Fedora_Draft_Documentation/0.1/html/RPM_Guide/ch-creating-rpms.html
cp ${XTWORKDIR}/lib/*.so.1 ${XTWORKDIR}/qt-client

cp ${XTWORKDIR}/qt-client/openrpt/lib/*.so.1 ${XTWORKDIR}/qt-client

#TODO: Include Designer

#TODO: Create a proper Desktop/Menu Entry.

#TODO: Grab all required libQt5 libs.
QTLIBPATH=/usr/local/Qt-5.5.1/lib

QTLIBS="libQt5CLucene.so.5 libQt5Core.so.5 libQt5DBus.so.5 \
    libQt5DesignerComponents.so.5 libQt5Designer.so.5 libQt5Gui.so.5 \
    libQt5Help.so.5 libQt5Network.so.5 libQt5OpenGL.so.5 \
    libQt5Positioning.so.5 libQt5PrintSupport.so.5 libQt5Qml.so.5 \
    libQt5Quick.so.5 libQt5Script.so.5 libQt5ScriptTools.so.5 \
    libQt5Sensors.so.5 libQt5SerialPort.so.5 libQt5Sql.so.5 \
    libQt5WebChannel.so.5 libQt5WebKit.so.5 libQt5WebKitWidgets.so.5 \
    libQt5WebSockets.so.5 libQt5Widgets.so.5 libQt5XcbQpa.so.5 \
    libQt5XmlPatterns.so.5 libQt5Xml.so.5 "

for QTLIB in ${QTLIBS}; do
cp ${QTLIBPATH}/${QTLIB} ${XTWORKDIR}/qt-client
done;


}



installEnv

# TODO: If /usr/local/Qt-5.5.1 exists then skip this
build_QT

build_xtuple

# makePackage

#TODO: Alternatively prompt for input
