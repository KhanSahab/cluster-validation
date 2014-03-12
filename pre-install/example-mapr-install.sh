#!/bin/bash
# jbenninghoff@maprtech.com 2013-Mar-20  vi: set ai et sw=3 tabstop=3:

cat - << 'EOF'
# Assumes clush is installed, available from EPEL repository
# Assumes all nodes have been audited with cluster-audit.sh and all issues fixed
# Assumes all nodes have met subsystem performance expectations as measured by memory-test.sh, network-test.sh and disk-test.sh
# Assumes MapR yum repo or repo mirror has been configured for all nodes and that MapR will run as mapr user
# Assumes jt, zkcldb and all group have been defined for clush
EOF
# Identify and format the data disks for MapR, destroys all data on all disks listed in /tmp/disk.list on all nodes
clush -Ba "lsblk -id | grep -o ^sd. | grep -v ^sda |sort|sed 's,^,/dev/,' | tee /tmp/disk.list; wc /tmp/disk.list"
exit

# Install all servers with minimal rpms to provide storage and compute plus NFS
clush -B -a 'yum -y install mapr-fileserver mapr-nfs mapr-tasktracker'

# Service Layout option #1 ====================
# Admin services layered over various data nodes
clush -B -g jt 'yum -y install mapr-jobtracker mapr-webserver mapr-metrics' # At least 2 JobTracker nodes
clush -B -g zkcldb 'yum -y install mapr-cldb mapr-webserver' # 3 CLDB nodes for HA, 1 does writes, all 3 do reads
clush -B -g zkcldb 'yum -y install mapr-zookeeper' #3 Zookeeper nodes, fileserver and nfs could be erased

# Service Layout option #2 ====================
# Admin services on dedicated nodes, uncomment the line below
#clush -B -w host1,host2,host3,host4,host5,host6,host7,host8 'yum -y erase mapr-tasktracker'

# Configure ALL nodes with CLDB and Zookeeper info (-N does not like spaces in the name)
clush -B -a "/opt/mapr/server/configure.sh -N MyCluster -Z $(nodeset -S, -e @zkcldb) -C $(nodeset -S, -e @zkcldb) -u mapr -g mapr"

# Identify and format the data disks for MapR
clush -B -a "lsblk -id | grep -o ^sd. | grep -v ^sda |sort|sed 's,^,/dev/,' | tee /tmp/disk.list; wc /tmp/disk.list"
clush -B -a '/opt/mapr/server/disksetup -F /tmp/disk.list'
#clush -B -a '/opt/mapr/server/disksetup -W $(cat /tmp/disk.list | wc -l) -F /tmp/disk.list' #Fast but less resilient storage

# Check for correct java version and set JAVA_HOME
clush -ab -o -qtt 'sudo sed -i "s,^#export JAVA_HOME=,export JAVA_HOME=/usr/java/jdk1.7.0_51," /opt/mapr/conf/env.sh'

clush -B -g zkcldb service mapr-zookeeper start; sleep 10
ssh host3 service mapr-warden start  # Start 1 CLDB and webserver
echo Wait at least 90 seconds for system to initialize; sleep 90

ssh host3 maprcli acl edit -type cluster -user mapr:fc
echo With a web browser, open this URL to continue with license installation:
echo 'https://host3:8443/'
echo
echo Start mapr-warden on all remaining servers once the license is applied
