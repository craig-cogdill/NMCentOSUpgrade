#!/bin/bash
# Make a USB stick for NetMon install on unknown disk layout.
# Prerequisite - System must have installed the following:
#  $ sudo yum install createrepo.noarch
#  $ sudo yum install epel-release
#  $ sudo yum install syslinux-extlinux.x86_64
#  $ sudo yum install wget.x86_64
#  $ sudo yum install genisoimage

if [[ $# -ne 3 ]] && [[ $# -ne 4 ]]
  then
    echo "Usage: $0 <version> <NMCentOSUpgrade-directory> <kickstart-build-directory> [buildRPMS-num]"
    echo "e.g., $0 2.1.2.244 /home/devdan/nm /home/devdan/kickstart"
    echo
    echo "   buildRPMS-num: if not using the latest build, it is necessary to specify"
    echo "                  the jenkins NM_REV1_Package build number, so the "
    echo "                  NM_rpms_<version>.tar.gz file can be found."
    exit
fi


export VERSION=$1
BVSIZE=`expr match "${VERSION}" '^[0-9]\+\.[0-9]\+\.[0-9]\+\|master'`
if [ $BVSIZE -eq 0 ]
  then
    echo "Bad version supplied: ${VERSION}"
    exit
fi
BASEVERSION=`expr substr $VERSION 1 $BVSIZE`
BASE=$2
NMCENTOSUPGRADE="${2}/NMCentOSUpgrade"
BASEINSTALL="${2}/NMBaseInstall_"${VERSION}
KSBUILD="${3}/${VERSION}"_UsbDynamic
BUILDRPMSNUM=lastSuccessfulBuild
ISOMOUNT="/mnt/iso"
if [ ! -z "$4" ]
  then
    BUILDRPMSNUM=$4
fi

echo; echo
echo VERSION = $VERSION
echo BASEVERSION = $BASEVERSION 
echo BASE = $BASE
echo NMCENTOSUPGRADE = $NMCENTOSUPGRADE
echo BASEINSTALL = $BASEINSTALL
echo KSBUILD = $KSBUILD
echo BUILDRPMSNUM = $BUILDRPMSNUM
echo ISOMOUNT = $ISOMOUNT
echo; echo

set -e
if [ ! -d "$BASE" ]
  then
    mkdir -p $BASE
fi

if [ ! -d "$BASEINSTALL" ]
  then
    echo "${BASEINSTALL} directory not found. Cloning NMBaseInstall"
    cd $BASE
    git clone http://lrgit/Logrhythm/NMBaseInstall.git $BASEINSTALL
    cd $BASEINSTALL
    git checkout remotes/origin/${BASEVERSION}
fi

if [ -d "$KSBUILD" ]
  then
    echo "${KSBUILD} already exists"
    exit
fi

# Mount the CentOS minimal install ISO image
echo "sudo commands used for mounting the iso image"
if [ ! -d $ISOMOUNT ]
  then
    sudo mkdir $ISOMOUNT
fi
sudo mount -o loop ${BASEINSTALL}/iso/CentOS-7-x86_64-Minimal-1511.iso ${ISOMOUNT}

# Create the kickstart build directory structure
mkdir -p $KSBUILD
cd $KSBUILD
mkdir USB_build

# Copy all the files from /mnt/iso into the USB_build directory.
cp -r ${ISOMOUNT}/* ${KSBUILD}/USB_build

# Copy the minimal repo xml file from /mnt/iso/repodata into the USB_build
# directory. Rename the file to minimal-x86_64.xml
cp ${ISOMOUNT}/repodata/c30db98d87c9664d3e52acad6596f6968b4a2c6974c80d119137a804c15cdf86-c7-minimal-x86_64-comps.xml ${KSBUILD}/USB_build/minimal-x86_64.xml

# Finished with the ISO image
sudo umount $ISOMOUNT 

# Make all files writable by the user
chmod -R u+w ${KSBUILD}/USB_build/*

echo "Copy the kickstart files into the isolinux install."
mkdir -p ${KSBUILD}/USB_build/ks
# Add the kickstart upgrade script to repartition sda drive and reuse /pcap0 and /usr/local
cp ${NMCENTOSUPGRADE}/kickstart/ks.upgrade.cfg.usb ${KSBUILD}/USB_build/ks/ks.dynamic.cfg
# Add the post script which runs in a chroot environment
cat ${BASEINSTALL}/kickstart/post.chroot.sh >> ${KSBUILD}/USB_build/ks/ks.dynamic.cfg
# Add the post script which runs in a non chroot environment
cat ${BASEINSTALL}/kickstart/post.no.chroot.sh >> ${KSBUILD}/USB_build/ks/ks.dynamic.cfg
# Add the post script which runs a perl script to setup the ifcfg-* files
cat ${BASEINSTALL}/kickstart/post.ifcfg.setup.pl >> ${KSBUILD}/USB_build/ks/ks.dynamic.cfg

cp ${BASEINSTALL}/kickstart/ks.customdisk.cfg.usb ${KSBUILD}/USB_build/ks/ks.customdisk.cfg
# Add the post script which runs in a chroot environment
cat ${BASEINSTALL}/kickstart/post.chroot.sh >> ${KSBUILD}/USB_build/ks/ks.customdisk.cfg
# Add the post script which runs in a non chroot environment
cat ${BASEINSTALL}/kickstart/post.no.chroot.sh >> ${KSBUILD}/USB_build/ks/ks.customdisk.cfg
# Add the post script which runs a perl script to setup the ifcfg-* files
cat ${BASEINSTALL}/kickstart/post.ifcfg.setup.pl >> ${KSBUILD}/USB_build/ks/ks.customdisk.cfg

cp ${BASEINSTALL}/kickstart/ks.centos.cfg.usb ${KSBUILD}/USB_build/ks/ks.centos.cfg

# Copy the isolinux_dynamic_usb.cfg file from NMBaseInstall/kickstart location to USB_build/isolinux/isolinux.cfg. Use
# the VERSION in the LABEL designations in the file.
sed "s/NetMon_master/NetMon_${VERSION}/g" ${BASEINSTALL}/kickstart/isolinux_dynamic_usb.cfg > ${KSBUILD}/USB_build/isolinux/isolinux.cfg

# Copy the LogRhythm splash screen from NMBaseInstall/kickstart location to USB_build/isolinux/splash.png
cp ${BASEINSTALL}/kickstart/NMSplash.png ${KSBUILD}/USB_build/isolinux/splash.png

# Get the RPM set for this release from Jenkins.
cd ${KSBUILD}/USB_build/Packages
wget http://nmbuild.logrhythm.com:8080/view/Build%20Pipeline/job/package/${BUILDRPMSNUM}/artifact/NM_rpms_${VERSION}.tar.gz

tar xzvf NM_rpms_${VERSION}.tar.gz
rm -f ${KSBUILD}/USB_build/Packages/NM_rpms_${VERSION}.tar.gz

#Test to make sure all RPM dependencies are met.
if [ -e /tmp/testdb ]; then
   rm -rf /tmp/testdb
fi
mkdir /tmp/testdb
rpm --initdb --dbpath /tmp/testdb
rpm --test --dbpath /tmp/testdb -Uvh *.rpm || true

echo; echo
echo "Hit Enter if all RPM dependencies are met, otherwise <ctrl>-c and fix dependencies"
read CONTINUE

#Create the new repo
cd ${KSBUILD}/USB_build
createrepo -g ${KSBUILD}/USB_build/minimal-x86_64.xml ${KSBUILD}/USB_build

# Make the new iso file with the kickstart cfg files included in it:
genisoimage -o "../nm_install_${VERSION}.iso.usb" -v -J -R -D -A "Install LogRhythm Network Monitor ${VERSION}" -V "NetMon_${VERSION}" -joliet-long -no-emul-boot -boot-info-table -boot-load-size 4 -b isolinux/isolinux.bin -c isolinux/boot.cat .

# Make the iso image bootable from a USB stick
isohybrid -v ../nm_install_${VERSION}.iso.usb

