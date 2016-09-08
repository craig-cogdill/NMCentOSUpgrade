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
echo "# Explicit return codes:" >> _lr_runup.sh
echo "#   0 - Success" >> _lr_runup.sh
echo "#  10 - Operating system is not 2.6.32-573.7.1" >> _lr_runup.sh
echo "#  11 - boot mount point is not found on sda1 partition" >> _lr_runup.sh
echo "#  12 - sda1 partition is not at expected location or not expected size" >> _lr_runup.sh
echo "#  13 - sda2 partition is not at expected location or not expected size" >> _lr_runup.sh
echo "#  14 - vg_probe00 is not found on sda2 partition" >> _lr_runup.sh
echo "#  15 - vg_probe01 is not found on sdb1 partition" >> _lr_runup.sh
echo "#  16 - lv_data is not found on vg_probe01 volume group" >> _lr_runup.sh
echo "#  17 - /dev/mapper/vg_probe01-lv_data is not mounted on /usr/local mount point" >> _lr_runup.sh
echo "#  18 - lv_pcapX is not found on vg_probe01 volume group" >> _lr_runup.sh
echo "#  19 - Removable media discovered on system" >> _lr_runup.sh

echo "set -e" >> _lr_runup.sh
# Parameter passed at runtime is the upgrade directory. If it isn't set then
# use the original /usr/local/probe/upload directory
echo "if [ -z \"\$1\" ]; then" >> _lr_runup.sh
echo "cd /usr/local/probe/upload" >> _lr_runup.sh
echo "else" >> _lr_runup.sh
echo "cd \$1" >> _lr_runup.sh
echo "fi" >> _lr_runup.sh

# Validate system: Can this system be upgraded? These checks are duplicated from the pre-check script,
# and are done here again to ensure the system is still in a qualified state to update.
echo "# Is the OS running the expected kernel?" >> _lr_runup.sh
echo "if ! uname -a | grep -q "2.6.32-573.7.1.el6.x86_64"; then" >> _lr_runup.sh
echo "   echo Unexpected OS Version." >> _lr_runup.sh
echo "   uname -a" >> _lr_runup.sh
echo "   exit 10" >> _lr_runup.sh
echo "fi" >> _lr_runup.sh

echo "# Is the boot mount point on sda1 partition?" >> _lr_runup.sh
echo "if ! lsblk | grep -q \"sda1.*/boot$\"; then" >> _lr_runup.sh
echo "   echo boot mount point not found on sda1 partition." >> _lr_runup.sh
echo "   lsblk" >> _lr_runup.sh
echo "   exit 11" >> _lr_runup.sh
echo "fi" >> _lr_runup.sh

echo "# Is the sda1 partition the expected size and location?" >> _lr_runup.sh
echo "if ! sfdisk -d /dev/sda | grep -q /dev/sda1[[:space:]]*:[[:space:]]*start=[[:space:]]*2048,[[:space:]]*size=[[:space:]]*1024000; then" >> _lr_runup.sh
echo "   echo sda1 partition is not at expected location or not expected size." >> _lr_runup.sh
echo "   sfdisk -d /dev/sda" >> _lr_runup.sh
echo "   exit 12" >> _lr_runup.sh
echo "fi" >> _lr_runup.sh

echo "# Is the sda2 partition the expected size and location?" >> _lr_runup.sh
echo "if ! sfdisk -d /dev/sda | grep -q /dev/sda2[[:space:]]*:[[:space:]]*start=[[:space:]]*1026048,[[:space:]]*size=[[:space:]]*583817216; then" >> _lr_runup.sh
echo "   echo sda2 partition is not at expected location or not expected size." >> _lr_runup.sh
echo "   sfdisk -d /dev/sda" >> _lr_runup.sh
echo "   exit 13" >> _lr_runup.sh
echo "fi" >> _lr_runup.sh

echo "# Is there a vg_probe00 volume group on sda2 partition?" >> _lr_runup.sh
echo "if ! lsblk | grep -A 3 sda2 | grep -q vg_probe00; then" >> _lr_runup.sh
echo "   echo vg_probe00 not found on sda2 partition" >> _lr_runup.sh
echo "   lsblk" >> _lr_runup.sh
echo "   exit 14" >> _lr_runup.sh
echo "fi" >> _lr_runup.sh

echo "# Is there a vg_probe01 volume group on sdb1 partition?" >> _lr_runup.sh
echo "if ! lsblk | grep -A 2 sdb1 | grep -q vg_probe01; then" >> _lr_runup.sh
echo "   echo vg_probe01 not found on sdb1 partition" >> _lr_runup.sh
echo "   lsblk" >> _lr_runup.sh
echo "   exit 15" >> _lr_runup.sh
echo "fi" >> _lr_runup.sh

echo "# Is lv_data logical volume on vg_probe01 volume group?" >> _lr_runup.sh
echo "if ! lvm lvs 2>&1 | grep -q lv_data[[:space:]]*vg_probe01; then" >> _lr_runup.sh
echo "   echo lv_data logical volume not found on vg_probe01 volume group" >> _lr_runup.sh
echo "   lvm lvs 2>/dev/null" >> _lr_runup.sh
echo "   exit 16" >> _lr_runup.sh
echo "fi" >> _lr_runup.sh

echo "# Is /dev/mapper/vg_probe01-lv_data mounted on /usr/local mount point?" >> _lr_runup.sh
echo "if ! mount | grep -q \"/dev/mapper/vg_probe01-lv_data on /usr/local\"; then" >> _lr_runup.sh
echo "   echo /dev/mapper/vg_probe01-lv_data is not mounted on /usr/local mount point" >> _lr_runup.sh
echo "   mount" >> _lr_runup.sh
echo "   exit 17" >> _lr_runup.sh
echo "fi" >> _lr_runup.sh

echo "# Is lv_pcapX logical volume on vg_probe01 volume group?" >> _lr_runup.sh
echo "if ! lvm lvs 2>&1 | grep -q lv_pcap[012]*[[:space:]]*vg_probe01; then" >> _lr_runup.sh
echo "   echo lv_pcapX logical volume not found on vg_probe01 volume group" >> _lr_runup.sh
echo "   lvm lvs 2>/dev/null" >> _lr_runup.sh
echo "   exit 18" >> _lr_runup.sh
echo "fi" >> _lr_runup.sh

echo "# Is removable media plugged into the system?" >> _lr_runup.sh
echo "removableFound=false" >> _lr_runup.sh
echo "for DEV in sda sdb sdc sdd sde; do" >> _lr_runup.sh
echo "   DIR="/sys/block"" >> _lr_runup.sh
echo "   if [ -d \$DIR/\$DEV ]; then" >> _lr_runup.sh
echo "      REMOVABLE=\`cat \$DIR/\$DEV/removable\`" >> _lr_runup.sh
echo "      if (( \$REMOVABLE == 1 )); then" >> _lr_runup.sh
echo "         echo \$DEV is removable" >> _lr_runup.sh
echo "         removableFound=true" >> _lr_runup.sh
echo "      else" >> _lr_runup.sh
echo "         echo \$DEV is not removable" >> _lr_runup.sh
echo "      fi" >> _lr_runup.sh
echo "   fi" >> _lr_runup.sh
echo "done" >> _lr_runup.sh
echo "if [ "\$removableFound" = "true" ]; then" >> _lr_runup.sh
echo "   echo Removable media found on the system" >> _lr_runup.sh
echo "   exit 19" >> _lr_runup.sh
echo "fi" >> _lr_runup.sh

echo "# If the script has not exited at this point, all system checks passed. Upgrade the system." >> _lr_runup.sh
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

echo "exec shutdown -r +1 &" >> _lr_runup.sh
echo "exit 0" >> _lr_runup.sh

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
