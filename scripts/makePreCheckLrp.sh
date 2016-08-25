#!/bin/bash
# Make a LogRhythm Upgrade package (lrp) to patch www files and check system for suitability for upgrading.
# Return codes:
#   1 - System is good for running upgrade
#  10 - Operating system is not 2.6.32-573.7.1
set -e
if [ -z "$1" ]
  then
    echo "Usage: $0 <version>"
    exit;
fi

VERSION=$1

echo "#!/bin/bash" > _lr_runup.sh
echo "# LogRhythm Upgrade pre-check" >> _lr_runup.sh

echo "set -e" >> _lr_runup.sh
# Parameter passed at runtime is the upgrade directory. If it isn't set then
# use the original /usr/local/probe/upload directory
echo "if [ -z \"\$1\" ]; then" >> _lr_runup.sh
echo "cd /usr/local/probe/upload" >> _lr_runup.sh
echo "else" >> _lr_runup.sh
echo "cd \$1" >> _lr_runup.sh
echo "fi" >> _lr_runup.sh

# Validate system: Can this system be upgraded?
echo "if ! uname -a | grep -q "2.6.32-573.7.1.el6.x86_64"; then" >> _lr_runup.sh
echo "   echo Unexpected OS Version: \`uname -a\`" >> _lr_runup.sh
echo "   exit 10" >> _lr_runup.sh
echo "fi" >> _lr_runup.sh

# The www fileuploader does not allow files larger than 1 GB. Modify this files to allows 2 GB.
# The upgrade lrp is 1.2 GB.
echo "sed -i -e \"s/maxFileSize.*1000000000/maxFileSize: 2000000000/g\" /usr/local/www/probe/analyze/js/controllers/configuration/UpgradeCtrl.js" >> _lr_runup.sh
echo "sed -i -e \"s/max_file_size.*1000000000/max_file_size\' => 2000000000/g\" /usr/local/www/probe/data/models/FileUploader.php" >> _lr_runup.sh
echo "sed -i -e \"s/post_max_size.*1000000000/post_max_size\' => 2000000000/g\" /usr/local/www/probe/data/models/FileUploader.php" >> _lr_runup.sh

# Return 1 for this special upgrade package. This prevents the GUI from attempting to reboot the system.
echo "exit 1" >> _lr_runup.sh

# Tar up the script to perform the pre-check upgrade
tar cvf upgrade.tar _lr_runup.sh
# Encrypt the tar
mcrypt -h sha512 -f ../resources/passphrase upgrade.tar

# Rename the encrypted file to the upgrade pre-check package name
mv upgrade.tar.nc upgrade-pre-check-$VERSION.lrp
