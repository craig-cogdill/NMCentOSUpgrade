#!/bin/bash
# Make a LogRhythm Upgrade package (lrp) for a special upgrade from CentOS 6.5 to 7.2
# Assumptions:
#  1. script is run out of NMCentOSUpgrade/scripts directory.
#  2. iso.usb file has been created in ~/kickstart/$VERSION_UsbDynamic
set -e
if [[ $# -ne 2 ]]
  then
    echo "Usage: $0 <version> <iso-usb-directory>"
    echo "e.g., $0 3.2.2.122 /home/devdan/kickstart/"
    exit 1;
fi

VERSION=$1
ISOUSBDIR="${2}/${VERSION}"_UsbDynamic
ISOUSB=nm_install_"${1}".iso.usb


echo; echo
echo VERSION = $VERSION
echo ISOUSBDIR = $ISOUSBDIR
echo ISOUSB = $ISOUSB
echo; echo

if [ ! -f "$ISOUSBDIR/$ISOUSB" ]; then
   echo ISO USB file not found: $ISOUSBDIR/$ISOUSB
   exit 2
fi

echo "#!/bin/bash" > _lr_runup.sh
echo "# Install LogRhythm Upgrade" >> _lr_runup.sh

echo "set -e" >> _lr_runup.sh
# Parameter passed at runtime is the upgrade directory. If it isn't set then
# use the original /usr/local/probe/upload directory
echo "if [ -z \"\$1\" ]; then" >> _lr_runup.sh
echo "cd /usr/local/probe/upload" >> _lr_runup.sh
echo "else" >> _lr_runup.sh
echo "cd \$1" >> _lr_runup.sh
echo "fi" >> _lr_runup.sh

echo "if ! uname -a | grep -q "2.6.32-573.7.1.el6.x86_64"; then" >> _lr_runup.sh
echo "   echo Unexpected OS Version: \`uname -a\`" >> _lr_runup.sh
echo "   exit 10" >> _lr_runup.sh
echo "fi" >> _lr_runup.sh

echo "# Install and configure grub2" >> _lr_runup.sh
echo "rpm -Uvh --force grub-2.02.beta3-1.el6.x86_64.rpm" >> _lr_runup.sh
echo "grub-install /dev/sda" >> _lr_runup.sh
echo "rm /boot/grub/grub.conf" >> _lr_runup.sh
echo "grub-mkconfig -o /boot/grub/grub.cfg" >> _lr_runup.sh

echo "# Save the initial ram disk used to reformat the sda drive" >> _lr_runup.sh
echo "cp initrd-nuclear.img /boot/" >> _lr_runup.sh

echo "# Move the iso image so it does not get deleted during sda drive reformatting" >> _lr_runup.sh
echo "mkdir -p /usr/local/iso" >> _lr_runup.sh
echo "mv nm_install_$VERSION.iso.usb /usr/local/iso/" >> _lr_runup.sh

echo "# Set up grub2 menu to do special boot operations." >> _lr_runup.sh
echo "# First reboot: reformat sda drive, and prepare for installing CentOS 7.2 with new Network Monitor." >> _lr_runup.sh
echo "# Second reboot: install from the iso file." >> _lr_runup.sh
echo "sed -i -e \"s/VERSION/$VERSION/g\" grub_menu_options" >> _lr_runup.sh
echo "cat grub_menu_options >> /usr/local/etc/grub.d/40_custom" >> _lr_runup.sh
echo "grub-mkconfig -o /boot/grub/grub.cfg" >> _lr_runup.sh
echo "grub-reboot 2" >> _lr_runup.sh

echo "shutdown -r +1" >> _lr_runup.sh

echo Tar up the files and the scripts to perform the upgrade:
tar cvf upgrade.tar \
   _lr_runup.sh \
   -C ../resources/ \
   grub_menu_options \
   initrd-nuclear.img \
   grub-2.02.beta3-1.el6.x86_64.rpm \
   -C $ISOUSBDIR \
   $ISOUSB

# Encrypt the tar
mcrypt -h sha512 -f ../resources/passphrase upgrade.tar

# Rename the encrypted file to the upgrade package name
mv upgrade.tar.nc upgrade-centos-$VERSION.lrp

echo
echo lrp package created: upgrade-centos-$VERSION.lrp
echo
