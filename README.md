# NMCentOSUpgrade
Scripts and packaging needed to create an LRP that can upgrade a legacy CentOS 6.5 system to CentOS 7.2

### Workflow

cd into the scripts directory and run the following scripts:
<pre><code>
    ./makeNmUsbUpgrade.sh <version> <NMCentOSUpgrade-directory> <kickstart-build-directory> [buildRPMS-num]
    ./makePreCheckLrp.sh <version>
    ./makeUpgradeLrp.sh <version> <iso-usb-directory>
</code></pre>

for example:
<pre><code>
    ./makeNmUsbUpgrade.sh 3.2.1.108 /home/jgress/wk /home/jgress/kickstart 71
    ./makePreCheckLrp.sh 3.2.1.108
    ./makeUpgradeLrp.sh 3.2.1.108 /home/jgress/kickstart
</code></pre>

### Theory
It is possible to boot an iso image from a physical partition using grub2. To upgrade NetMon with CentOS 6.5 to NetMon with CentOS 7.2 using an lrp, the following is necessary:<br>
1. Install and configure grub2 on the CentOS 6.5 system.<br>
2. Delete the existing physical volume on the sda2 partition which contains the root, home, and swap logical volumes.<br>
3. Recreate a new sda partitioning to add a third partition large enough to hold the iso image.<br>
4. Create an ext2 file system on the new sda3 partition, and copy the iso image into that partition<br>
5. Modify the initramfs-2.6.32-573.7.1.el6.x86_64.img to perform the repartitioning. The "init" script in the initramfs is modified to do the following:<br>

  * Repartition the sda drive as described above.
  * Copy the iso image into the sda3 partition.
  * Reboot the system and run the iso image.

6. The iso image must be properly prepared to recreate the root, home, and swap partitions while reusing the existing /usr/local and pcap partitions. The iso image must also be able to move the metadata and configuration in /usr/local to a saved location during the install and then recover the saved data so it is available when the upgraded system starts up.<br>

### lrp contents
  * Upgrade iso.usb file
  * Modified initrd-nuclear.img file
  * grub custom menu options file
  * grub2 rpm file
  * script to check system for suitability to perform the upgrade successfully
  * script to install and configure grub2
  * script to copy iso and initrd files to proper locations
  * script to save metadata and configuration
  * script to configure grub to reboot with option 2 and reboot the system.

### Assumptions about upgrade target
  * System is running 2.6.32-573.7.1.el6.x86_64 linux kernel.
  * System has /boot partition on /dev/sda1 partition.
  * System has /dev/sda1 partition starting at sector 2048 and size 1024000.
  * System has /dev/sda2 partition starting at sector 1026048 and size 583817216.
  * System has vg_probe00 volume group allocated on /dev/sda2 partition.
  * System has vg_probe01 volume group allocated on /dev/sdb1 partition.
  * System has lv_data logical volume on vg_probe01 volume group.
  * System has lv_pcapX logical volume on vg_probe01 volume group, where X is blank, 0, 1, or 2.
  * /dev/mapper/vg_probe01-lv_data is mounted on /usr/local mount point.
  * Removable disk media (USB drives) are not connected to the system.

### Building a custom nuclear initrd image
  * Start with the /boot/initramfs-2.6.32-573.7.1.el6.x86_64.img
  * unpack the initramfs from the /boot directory. For example:
    * `mkdir initrd`
    * `cd initrd`
    * `gunzip -c /boot/initramfs-2.6.32-573.7.1.el6.x86_64.img | cpio -i –make-directories`

#### Modify the contents of the initrd directory

  * Add sdaDiskPart to initrd:
<pre><code>
    # partition table of /dev/sda
    unit: sectors

    /dev/sda1 : start=     2048, size=  1024000, Id=83, bootable
    /dev/sda2 : start=  1026048, size=114483200, Id=8e
    /dev/sda3 : start=115509248, size= 10240000, Id=83
    /dev/sda4 : start=        0, size=        0, Id= 0
</code></pre>

#### Modify the init script
  * Add the following to the init script just after the `rdbreak=initqueue`:
<pre><code>
    [ -x /bin/plymouth ] && /bin/plymouth --hide-splash
    echo
    echo
    echo Nuclear Option - reformat sda drive
    sleep 3
    # Delete any remnants of the root physical volume with its volume group and logical volumes.
    echo Delete the root physical volume
    echo
    echo
    /sbin/lvm pvremove -ff -y /dev/sda2
    /bin/dd if=/dev/zero of=/dev/sda2 count=1k bs=16k
    sleep 1
    
    # Format the sda drive with new partitions
    /sbin/sfdisk --force /dev/sda < /sdaDiskPart
    sleep 1
    # reload the new disk partitioning into the kernel
    /sbin/hdparm -z /dev/sda
    sleep 1
    /sbin/mkfs.ext2 /dev/sda3
    echo sda drive reformated
    echo
    echo
    ls -lh /dev/sda\*
    echo
    echo
    sleep 2
</code></pre>

  * Add the following to the init script just after the `source_all pre-mount`:
<pre><code>
    echo
    echo
    echo Copy iso image to new sda3 partition ...
    echo
    echo
    mkdir /usrlocal
    mount /dev/mapper/vg_probe01-lv_data /usrlocal
    mkdir /lrup
    mount /dev/sda3 /lrup
    
    cp /usrlocal/iso/nm_install* /lrup/
    
    echo Waiting for unmount of lrup partition.
    until umount /lrup
    do
       echo Waiting for unmount of lrup partition.
       sleep 1
    done
    echo
    echo
    echo iso image copied to sda3 partition
    echo
    echo
    
    # The third grub boot menu option is to install from the iso file in sda3
    echo Change grub to boot the third menu option on next boot
    mkdir /boot
    mount /dev/sda1 /boot
    sed -i -e "s/next_entry=.*$/next_entry=3/g" /boot/grub/grubenv
    echo Waiting for unmount of boot partition
    until umount /boot
    do
       echo Waiting for unmount of boot partition
       sleep 1
    done
    sleep 2
    # Reboot the system
    echo b > /proc/sysrq-trigger
</code></pre>


#### Add necessary tools to initrd directory

  * `cp /sbin/sfdisk sbin/`
  * `cp /sbin/mkfs.ext2 sbin/`
  * `cp -a /lib64/libext2fs.so.2* lib64/`
  * `cp -a /lib64/libcom_err.so.2* lib64/`
  * `cp -a /lib64/libe2p.so.2* lib64/`
  * `yum install hdparm-9.43-4.el6.x86_64`
  * `cp /sbin/hdparm sbin/`

#### Creating a new initrd-nuclear.img
  * From the initrd directory:
    * `find ./ | cpio -H newc -o >/tmp/initrd-cpio`
    * `gzip -c /tmp/initrd.cpio > /boot/initrd-nuclear.img`

### Data to be saved before upgrading
  * /usr/local/probe/db/elasticsearch/data entire directory structure should be moved to /usr/local/save/data
    * Looks like elasticsearch install leaves the data directory as is, so this doesn't need to be moved.
  * Move /usr/local/probe/conf/\* files to /usr/local/save/conf
  * Move /usr/local/probe/userLua/\* files to /usr/local/save/userLua
  * Timezone setting
  * NTP settings
  * /usr/local/probe/apiLua/usr/\* files to /usr/local/save/apiLua/usr


### Post Install steps
  * chown files that need new ownership
    * `chown -R elasticsearch:dpi /usr/local/probe/db/elasticsearch/data`
    * `chown -R dpi:dpi /pcap0`
  * Set management interface in /etc/sysconfig/network-scripts/ifcfg-xxx to match conf/nm.yaml.Interface; restore nm.yaml.Interface to /usr/local/probe/conf
  * Restore nm.yaml settings saved in /usr/local/save/conf/nm.yaml
    * Can the entire nm.yaml file be restored?
    * pcapInterface may need to be updated to modify ethX or other non bond0 setting.
  * Restore apiLua/usr/\* files to /usr/local/probe/apiLua/usr
  * Set system NTP configuration to match previous settings.
  * Set timezone (Maybe this can be done in the grub menu when booting from the iso.)
