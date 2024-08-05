## mount disk <2TB
printf "p\nn\np\n1\n\n\nt\n8e\np\nw" | sudo fdisk /dev/sdb
pvcreate /dev/sdb1
vgcreate VG00 /dev/sdb1
lvcreate -l 100%FREE -n LV_data VG00
mkfs.xfs /dev/VG00/LV_data
mkdir /data
echo "/dev/mapper/VG00-LV_data /data xfs defaults 0 0" >> /etc/fstab
mount -a 

sudo chown -R cmpprod:cmpprod /data 
## verify disk mounted
df -h 
 ##------------------------------------------------------------------------------------
## Create "cmpprod" User

groupadd -g 1001 cmpprod
useradd -m -g 1001 -u 1001 -c cmpprod -s /bin/bash cmpprod
touch /home/cmpprod/.rhosts
echo "export TMOUT=1800" >> /home/cmpprod/.bash_profile
echo "umask 0022" >> /home/cmpprod/.bash_profile
echo "cmpprod ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/cmpprod
passwd cmpprod
##------------------------------------------------------------------------------------
## set file hosts
vi /etc/hosts
192.168.56.111 es1
192.168.56.112 es2
...
sudo vi /etc/security/limits.conf 
cmpprod - nproc 65536
cmpprod - memlock unlimited

sudo vi /etc/sysctl.conf 
vm.max_map_count=262144
##apply config with command:
sudo sysctl -p
##--------------------------------------------------------------------------------------
## Install Java
## if on server already install old version of Java
## remove old version jdk
sudo yum remove -y cairo-gobject-* harfbuzz-icu-* mesa-libGLES-* avahi-glib-* avahi-gobject-* dbus-x11-* cups-client-* cups-* avahi-ui-gtk3-* libX11-1.6.5-2.el7.x86_64
tar -xzvf /tmp/java.tar.gz -C /tmp/
sudo yum -y localinstall /tmp/package/*.rpm
##---------------------------------------------------------------------------------
## install zip
rpm -Uvh /tmp/zip-.rpm 

# Create directory
mkdir -p /data/es/nodes
mkdir -p /data/logs/es 
##-------------------------------------------------------------------------------------
# extract elasticsearch
cd /home/cmpprod/
tar -xvzf /tmp/elasticsearch.tar.gz
ln -s /home/cmpprod/elasticsearch-7.12.1 /home/cmpprod/elasticsearch
##----------creat cert---------------------------------------------------------------------------------------------------------------------
vi /tmp/instance.yml

inatances:
- name: 'es1'
  ip: [ '192.168.56.111' ]
- name: 'es1'
  ip: [ '192.168.56.111' ] 
  
/home/cmpprod/elasticsearch/bin/elasticsearch-certutil cert --keep-ca-key --days 9999 --pem --in /tmp/instance.yml --out /tmp/certs.zip 
## copy file cert.zip into all node 
scp /tmp/certs.zip cmpprod@1....:/tmp

## add cert----------------------------------------------------------------------------------------------------------
mkdir /home/cmpprod/elasticsearch/config/cert
unzip /tmp/certs.zip -d /tmp/

cp /tmp/ca/ca.crt /home/cmpprod/elasticsearch/config/cert/.
cp /tmp/es1/es1.crt /home/cmpprod/elasticsearch/config/cert/.
cp /tmp/es1/es1.key /home/cmpprod/elasticsearch/config/cert/.

## config file elasticsearch.yml-------------------------------------------------------------------------------------
vi /home/cmpprod/elasticsearch/config/elasticsearch.yml

node.name: es1 
node.roles: [master, data]
cluster.name: fw-log 

bootstrap.memory_lock:true 
network.host: 192.....
discovery.seed_hosts: ["192.168....","192.168","...."]
cluster.initial_master_nodes: ["ip master","ip"]

xpack.security.enabled: true 
xpack.security.transport.ssl.enabled: true 
xpack.security.transport.ssl.key: /home/cmpprod/elasticsearch/config/cert/es1.key 
xpack.security.transport.ssl.certificate: home/cmpprod/elasticsearch/config/cert/es1.crt
xpack.security.transport.ssl.certificate_authorities: home/cmpprod/elasticsearch/config/cert/ca.crt 

##--------config jvm-----------------------------------------------------------------------------------------------------
vi /home/cmpprod/elasticsearch/config/jvm.options
-Xms8g
-Xmx8g

##---create file elasticsearch.service------------------------------------------------------------
sudo vi /etc/systemd/system/elasticsearch.service

[Unit]
Description=Elasticsearch
Documentation=http://www.elastic.co
Wants=network-online.target
After=network-online.target

[Service]
User=cmpprod
Group=cmpprod
Type=simple
#Restart=alway

RuntimeDirectory=elasticsearch
PrivateTmp=true
Environment=ES_HOME=/home/cmpprod/elasticsearch
Environment=ES_PATH=/home/cmpprod/elasticsearch
Environment=PID_DIR=/var/run/elasticsearch
WorkingDirectory=/home/cmpprod//elasticsearch

ExecStart=/home/cmpprod//elasticsearch/bin/elasticsearch -p ${PID_DIR}/elasticsearch.pid --quiet

#StandardOutput is configured to redi
#some error messages may be logged
#elasticsearch loggig system is initialized
#stores its
# journalctl by default/elasticsearch
# Logging, you can simply

StandardOutput=journal
StandardError=inherit

# Specifies the maximum file descriptor number that can be opened by this process
LimitNOFILE=65535

# Specifies the maximum number of process
LimitNPROC=4096

#Specifies the maximum size of virtual memory
LimitAS=infinity

#Specifies the maximum file size
LimitFSIZE=infinity

#Disable timeout logic and wait Unit process is stopped
TimeoutStopSec=0

# SIGTERM signal is used to stop the Java process
KillSignal=SIGTERM

# Send the signal only to the JVM rather than its control Group 
KillMode=process

# Java process is never killed
SendSIGKILL=no

# When a JVM receives a SIGTERM signal it exits with code 143
SuccessExitStatus=143

# Allow a slow startup before the systemd notifier module kick
TimeoutStartSec=75

LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target

## ---------Run elasticsearch service---------------------------------------------------------------
sudo systemctl enable Elasticsearch
sudo systemctl start Elasticsearch
sudo systemctl status Elasticsearch
## Active built-in user "elastic"--------------------------------------------------------------------------

Password "cmpdev3#"
/home/cmpprod//elasticsearch/bin/elasticsearch-setup-passwords interactive
##when the message please confirm that you would like to continue y/n appears
-----------------------------------------------------------------------------------------------------------