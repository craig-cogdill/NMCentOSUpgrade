#!/bin/bash
# Make a LogRhythm Upgrade package (lrp) for a special upgrade from CentOS 6.5 to 7.2
# Assumptions:
#  1. script is run out of NMCentOSUpgrade/scripts directory.
#  2. iso.usb file has been created in ~/kickstart/3.2.1.108_UsbDynamic
set -e
if [ -z "$1" ]
  then
    echo "Usage: $0 <version>"
    exit;
fi

VERSION=$1

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
echo "   exit 1" >> _lr_runup.sh
echo "fi" >> _lr_runup.sh

echo "rpm -Uvh --force grub-2.02.beta3-1.el6.x86_64.rpm" >> _lr_runup.sh
echo "grub-install /dev/sda" >> _lr_runup.sh
echo "rm /boot/grub/grub.conf" >> _lr_runup.sh
echo "grub-mkconfig -o /boot/grub/grub.cfg" >> _lr_runup.sh
echo "cp initrd-nuclear.img /boot/" >> _lr_runup.sh
echo "mkdir -p /usr/local/iso" >> _lr_runup.sh
echo "mv nm_install_3.2.1.108.iso.usb /usr/local/iso/" >> _lr_runup.sh
echo "cat grub_menu_options >> /usr/local/etc/grub.d/40_custom" >> _lr_runup.sh
echo "grub-mkconfig -o /boot/grub/grub.cfg" >> _lr_runup.sh
echo "grub-reboot 2" >> _lr_runup.sh
echo "shutdown -r +1" >> _lr_runup.sh

# Tar up the files and the scripts to perform this upgrade
tar cvf upgrade.tar \
   _lr_runup.sh \
   -C ../resources/ \
   grub_menu_options \
   initrd-nuclear.img \
   grub-2.02.beta3-1.el6.x86_64.rpm \
   -C ~/kickstart/3.2.1.108_UsbDynamic/ \
   nm_install_3.2.1.108.iso.usb
# Encrypt the tar
mcrypt -h sha512 -f ../resources/passphrase upgrade.tar

# Rename the encrypted file to the upgrade package name
mv upgrade.tar.nc upgrade-centos-$VERSION.lrp
