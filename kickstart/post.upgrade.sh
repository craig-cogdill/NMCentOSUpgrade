# This post script is run in chroot environment.
%post --log=/root/ks-post-upgrade.log
#!/bin/bash

echo Update ownership and recovery files from CentOS 6.5 installation.

# Recover elasticsearch data
mv /usr/local/save/elasticsearch/data /usr/local/probe/db/elasticsearch/

# Change owner:group settings to match the new UID:GID on the new OS. 
echo Updating elasticsearch:dpi ownership on db/elasticsearch/data directory
chown -R elasticsearch:dpi /usr/local/probe/db/elasticsearch/data

for dir in /pcap*; do
   echo Updating dpi ownership on $dir
   chown -R dpi:dpi $dir
done


# Recover userLua Rules.
# Change owner:group for saved userLua rules.
chown -R dpi:dpi /usr/local/save/userLua
# Copy userLua rules which are not matching rules already in /usr/local/probe/userLua.
cd /usr/local/save/userLua
for file in *; do
   if [ ! -f /usr/local/probe/userLua/$file ]; then
# TODO exclude system rules which have been deleted from NMSystemRules repo.
      echo "Recovering $file"
      cp /usr/local/save/userLua/$file /usr/local/probe/userLua
   fi
done
# Enusre the files copied to probe/userLua get the updated dpi ownership.
chown -R dpi:dpi /usr/local/probe/userLua

# Recover pcap capture settings
# Change owner:group for saved apiLua/usr rules.
chown -R dpi:nobody /usr/local/save/apiLua/usr
# Recover all apiLua/usr settings
cp /usr/local/save/apiLua/usr/* /usr/local/probe/apiLua/usr/
# Enusre the files copied to apiLua/usr get the updated dpi ownership.
chown -R dpi:nobody /usr/local/probe/apiLua/usr

%end

