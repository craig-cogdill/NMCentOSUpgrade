#!/bin/bash
# Make a LogRhythm Upgrade package (lrp) to patch www files and check system for suitability for upgrading.
set -e
if [ -z "$1" ]
  then
    echo "Usage: $0 <version>"
    exit;
fi

VERSION=$1

echo "#!/bin/bash" > _lr_runup.sh
echo "# LogRhythm Upgrade pre-check" >> _lr_runup.sh
echo "# Return codes:" >> _lr_runup.sh
echo "#   1 - System is good for running upgrade; management interface is on the motherboard" >> _lr_runup.sh
echo "#   2 - System is good for running upgrade, but management interface is not on the motherboard" >> _lr_runup.sh
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
echo "   cd /usr/local/probe/upload" >> _lr_runup.sh
echo "else" >> _lr_runup.sh
echo "   cd \$1" >> _lr_runup.sh
echo "fi" >> _lr_runup.sh

echo "echo" >> _lr_runup.sh

# Validate system: Can this system be upgraded?
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

echo "# If the script has not exited at this point, all system checks passed. Prepare the system for upgrading." >> _lr_runup.sh
echo "# The www fileuploader does not allow files larger than 1 GB. Modify this files to allows 2 GB." >> _lr_runup.sh
echo "# The upgrade lrp is 1.2 GB." >> _lr_runup.sh
echo "sed -i -e \"s/maxFileSize.*1000000000/maxFileSize: 2000000000/g\" /usr/local/www/probe/analyze/js/controllers/configuration/UpgradeCtrl.js" >> _lr_runup.sh
echo "sed -i -e \"s/max_file_size.*1000000000/max_file_size\' => 2000000000/g\" /usr/local/www/probe/data/models/FileUploader.php" >> _lr_runup.sh
echo "sed -i -e \"s/post_max_size.*1000000000/post_max_size\' => 2000000000/g\" /usr/local/www/probe/data/models/FileUploader.php" >> _lr_runup.sh

echo "# Backup configuration data to be restored after the upgrade." >> _lr_runup.sh
echo "mkdir -p /usr/local/save/conf" >> _lr_runup.sh
echo "cp -a /usr/local/probe/conf/* /usr/local/save/conf/" >> _lr_runup.sh
echo "mkdir -p /usr/local/save/userLua" >> _lr_runup.sh
echo "cp -a /usr/local/probe/userLua/* /usr/local/save/userLua/" >> _lr_runup.sh

# Install rpm package for dmidecode tool
echo "rpm -Uv dmidecode-2.12-7.el6.x86_64.rpm" >> _lr_runup.sh

echo "# Is management interface on eth0 or em1?" >> _lr_runup.sh
echo "if ip address | grep -q eth0; then" >> _lr_runup.sh
echo "   echo Management interface is eth0" >> _lr_runup.sh
echo "   MGMT_INTF=eth0" >> _lr_runup.sh
echo "else" >> _lr_runup.sh
echo "   echo Management interface is em1" >> _lr_runup.sh
echo "   MGMT_INTF=em1" >> _lr_runup.sh
echo "fi" >> _lr_runup.sh


echo "# Check if management interface is on the motherboard or not" >> _lr_runup.sh
echo "BUSINFO=\`ethtool -i \$MGMT_INTF | grep bus-info\`" >> _lr_runup.sh
echo "# Extract the Bus Address from the bus info" >> _lr_runup.sh
echo "[[ \"\$BUSINFO\" =~ bus-info:[[:space:]]*([[:xdigit:]]{4}:[[:xdigit:]]{2}:[[:xdigit:]]{2}\.[[:xdigit:]]) ]]" >> _lr_runup.sh
echo "if ! dmidecode | grep -B 10 -i \${BASH_REMATCH[1]} | grep -q \"Onboard Device\"; then" >> _lr_runup.sh
echo "   echo Management interface is not on the motherboard." >> _lr_runup.sh
echo "   exit 2" >> _lr_runup.sh
echo "fi" >> _lr_runup.sh

echo "# Management interface is on motherboard" >> _lr_runup.sh
echo "echo Management interface is on the motherboard." >> _lr_runup.sh
echo "exit 1" >> _lr_runup.sh
echo "# Note: non-zero return prevents the GUI from attempting to reboot the system." >> _lr_runup.sh

# Tar up the script to perform the pre-check upgrade
tar cvf upgrade.tar \
   _lr_runup.sh \
   -C ../rpms/ \
   dmidecode-2.12-7.el6.x86_64.rpm 
# Encrypt the tar
mcrypt -h sha512 -f ../resources/passphrase upgrade.tar

# Rename the encrypted file to the upgrade pre-check package name
mv upgrade.tar.nc upgrade-pre-check-$VERSION.lrp
