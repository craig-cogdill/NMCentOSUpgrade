# This post script is run in chroot environment.
%post --log=/root/ks-post-upgrade.log
#!/bin/bash

# Change owner:group settings to match the new UID:GID on the new OS. 
chown -R elasticsearch:dpi /usr/local/probe/db/elasticsearch/data

for dir in /pcap*; do
   chown -R dpi:dpi $dir
done

%end

