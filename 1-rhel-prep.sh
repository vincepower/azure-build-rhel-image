#!/bin/bash
##
## RUN AS ROOT
##
## This script will take care of setting up ansible.cfg, ssh, and docker
##
## This script requires a golden image of RHEL to run on that is
## subscribed to RHSM or a Satelite Server and should be run before
## uploading to GCP.
##
## This script has a short URL to make it easier to download in the VM
## $ curl -o tmp.txt https://bit.ly/2REXak9
## Then edit tmp.txt to remove all the HTML around the URL
## $ curl -o run.sh `cat tmp.txt`
## 

#
echo "Make sure you are subscribed, then edit this"
echo "file and remove the 'exit' on the next line."
exit

# Add correct repositories from RHSM
echo "Disabling all repositories not required"
subscription-manager repos --disable="*"

echo "Ensuring required repositories are enabled"
subscription-manager repos \
    --enable="rhel-7-server-rpms" \
    --enable="rhel-7-server-extras-rpms" \
    --enable="rhel-7-server-ose-3.10-rpms" \
    --enable="rhel-7-server-ansible-2.6-rpms" \
    --enable="rhel-7-fast-datapath-rpms" \
    --enable="rh-gluster-3-client-for-rhel-7-server-rpms"

## Exposing exclusioned packages
echo "Installing and disabling OpenShift excluders"
yum install -y atomic-openshift-excluder atomic-openshift-docker-excluder
atomic-openshift-excluder unexclude

## Updating all packages
echo "Updating the OS"
yum update -y

## Installing required packages
echo "Installing prereqs"
yum install -y wget git net-tools bind-utils yum-utils iptables-services bridge-utils
yum install -y bash-completion kexec-tools sos psacct docker ntp
yum install -y cloud-init cloud-utils-growpart
yum install -y ansible glusterfs-fuse

# Installing Azure Utilities
echo "Installing Azure Agent"
yum install WALinuxAgent
systemctl enable waagent.service

# Adjusting the /etc/waagent.conf
sed -i -e "s/^ResourceDisk.EnableSwap=n/ResourceDisk.EnableSwap=y/" /etc/waagent.conf
sed -i -e "s/^ResourceDisk.SwapSizeMB=0/ResourceDisk.SwapSizeMB=2048/" /etc/waagent.conf

## Create ssh_config
echo "Updating ssh_config"
cat << EOF > /etc/ssh/ssh_config
# ssh_config for OCP on GCP
Host *
    Port 22
    Protocol 2
    ForwardAgent no
    ForwardX11 no
    HostbasedAuthentication no
    StrictHostKeyChecking no
    Ciphers aes128-ctr,aes192-ctr,aes256-ctr,arcfour256,arcfour128,aes128-cbc,3des-cbc
    Tunnel no
    ServerAliveInterval 420
EOF

## Create sshd_config
echo "Updating sshd_config"
cat << EOF > /etc/ssh/sshd_config
# sshd_config for OCP on GCP
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
SyslogFacility AUTHPRIV
PermitRootLogin yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
AllowTcpForwarding yes
X11Forwarding no
ClientAliveInterval 180
AcceptEnv LANG LC_CTYPE LC_NUMERIC LC_TIME LC_COLLATE LC_MONETARY LC_MESSAGES
AcceptEnv LC_PAPER LC_NAME LC_ADDRESS LC_TELEPHONE LC_MEASUREMENT
AcceptEnv LC_IDENTIFICATION LC_ALL LANGUAGE
AcceptEnv XMODIFIERS
Subsystem sftp  /usr/libexec/openssh/sftp-server
EOF

## Restart ssh daemon and wait for a few seconds before continuing
echo "Enabling and restarting sshd"
systemctl restart sshd
sleep 5

## Make go's home directory
echo "Creating the golang config"
mkdir -p /root/go/bin
echo "export GOPATH=/root/go" >> /root/.bashrc
echo "export PATH=\$PATH:/root/go/bin" >> /root/.bashrc

# Updating GRUB as per GCP's recommendations
echo "Setting the recommended grub config"
cat << EOF > /etc/default/grub
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX="rootdelay=300 console=tty0 console=ttyS0 earlyprintk=ttyS0 net.ifnames=0"
GRUB_DISABLE_RECOVERY="true"
EOF
sudo grub2-mkconfig -o /boot/grub2/grub.cfg

# Updating initramfs
cat < EOF >> /etc/dracut.conf.d/azure.conf
add_drivers+=" hv_vmbus hv_netvsc hv_storvsc "
EOF
dracut -f -v

# Creating eth0 config file
echo "Creating eth0 config file"
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-eth0
TYPE="Ethernet"
BOOTPROTO="dhcp"
DEFROUTE="yes"
PEERDNS="yes"
PEERROUTES="yes"
IPV4_FAILURE_FATAL="no"
IPV6INIT="no"
NAME="eth0"
DEVICE="eth0"
ONBOOT="yes"
EOF

# Enabling and configuring ntp
echo "Enabling ntp"
cat << EOF > /etc/ntp.conf
driftfile /var/lib/ntp/drift
restrict default nomodify notrap nopeer noquery
restrict 127.0.0.1
restrict ::1
server 0.north-america.pool.ntp.org
server 1.north-america.pool.ntp.org
server 2.north-america.pool.ntp.org
server 3.north-america.pool.ntp.org
includefile /etc/ntp/crypto/pw
keys /etc/ntp/keys
disable monitor
EOF
systemctl enable ntpd

# Sending some commands
echo ""
echo "You could unregister if you have a different ID for the cloud"
echo "  subscription-manager unregister"
echo ""
echo "To erase command line history use:"
echo "  export HISTSIZE=0"
echo ""

# End of script

