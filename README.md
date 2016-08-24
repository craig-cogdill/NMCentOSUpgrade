# NMCentOSUpgrade
Scripts and packaging needed to create an LRP that can upgrade a legacy CentOS 6.5 system to CentOS 7.2

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
  * script to stop ProbeReader and ProbeLogger
  * script to save metadata and configuration
  * script to configure grub to reboot with option 2 and reboot the system.

### Installing and configuring grub2:
  * rpm -Uvh --force grub-2.02.beta3-1.el6.x86_64.rpm
  * grub-install /dev/sda
  * rm /boot/grub/grub.conf
  * grub-mkconfig -o /boot/grub/grub.cfg

### Assumptions about upgrade target
  * System is running 2.6.32-573.7.1.el6.x86_64 linux kernel.
  * System has /boot partition on /dev/sda1 partition.
  * System has /dev/sda1 partition starting at section 2048 and size 1024000.
  * System does not have a removable disk (USB memory drive) plugged into the system.
  * System has vg_probe00 volume group allocated on /dev/sda2 partition.
  * System has vg_probe01 volume group allocated on /dev/sdb1 partition.
  * System has lv_data logical volume on vg_probe01 volume group.
  * /dev/mapper/vg_probe01-lv_data is mounted on /usr/local mount point.
  * /dev/sda drive is 299439751168 bytes in size; and total sectors is 584843264.

### Building a nuclear initrd image
  * Start with the /boot/initramfs-2.6.32-573.7.1.el6.x86_64.img
  * unpack the initramfs from the /boot directory. For example:
  * `mkdir initrd`
  * `cd initrd`
  * `gunzip -c /boot/initramfs-2.6.32-573.7.1.el6.x86_64.img | cpio -i –make-directories`

#### Creating a new initrd-nuclear.img
  * `find ./ | cpio -H newc -o >/tmp/initrd-cpio`
  * `gzip -c /tmp/initrd.cpio > /boot/initrd-nuclear.img`

#### Modify the contents of the initrd directory

  * Add sdaDiskPart to initrd:
<pre><code>
    # partition table of /dev/sda
    unit: sectors

    /dev/sda1 : start=     2048, size=  1024000, Id=83, bootable
    /dev/sda2 : start=  1026048, size=114483200, Id=8e
    /dev/sda3 : start=115509248, size= 10240000, Id=83
    /dev/sda4 : start=        0, size=        0, Id= 0
</code><pre>

#### Add necessary tools to initrd directory

  * `cp /sbin/sfdisk sbin/`
  * `cp /sbin/mkfs.ext2 sbin/`
  * `cp -a /lib64/libext2fs.so.2* lib64/`
  * `cp -a /lib64/libcom_err.so.2* lib64/`
  * `cp -a /lib64/libe2p.so.2* lib64/`
  * `yum install hdparm-9.43-4.el6.x86_64`
  * `cp /sbin/hdparm sbin/`
