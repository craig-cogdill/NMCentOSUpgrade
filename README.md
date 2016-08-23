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

