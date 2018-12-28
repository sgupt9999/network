#!/bin/bash
# DIFFERENCE FROM THE 1ST SCRIPT
# This script uses the route and rule files in the /etc/sysconfig/network-scripts directory to make
# persistent changes, instead of systemd script
#
# On AWS With multiple network cards with the default route tables the outbound public traffic keeps going out via the default interface
# This can be tested by running tcpdump on default interface and then sending a ping to the 2nd interface
# The second address will try to send return traffic via the 1st interface
# To fix this need to create a rule to direct traffic from second address through the 2nd network interface card
# Also creating a systemd service that will create the rules and routes on boot and also
# adding to the network.service so the script is also called when starting network


# User inputs
INTERFACE1="eth0"
INTERFACE2="eth1"
IP1=172.31.44.156/32
IP2=172.31.39.104/32
ROUTER1=172.31.32.1
ROUTER2=172.31.32.1
# End of user inputs

if [[ $EUID != "0" ]]
then
	echo "ERROR. You need root privileges to run this script"
	exit 1
fi

yum install wget -y

#### Make sure the file is available at this link
rm -rf NetworkManager-dispatcher-routing-rules-1.12.0-8.el7_6.noarch.rpm
wget https://rpmfind.net/linux/centos/7.6.1810/updates/x86_64/Packages/NetworkManager-dispatcher-routing-rules-1.12.0-8.el7_6.noarch.rpm
yum install NetworkManager-dispatcher-routing-rules-1.12.0-8.el7_6.noarch.rpm   
systemctl enable --now NetworkManager-dispatcher.service 
rm -rf NetworkManager-dispatcher-routing-rules-1.12.0-8.el7_6.noarch.rpm

echo "from $IP1 table 1 priority 100" > /etc/sysconfig/network-scripts/rule-$INTERFACE1
echo "from $IP2 table 2 priority 200" >> /etc/sysconfig/network-scripts/rule-$INTERFACE1

echo "default via $ROUTER1 dev $INTERFACE1 table 1" > /etc/sysconfig/network-scripts/route-$INTERFACE1
echo "default via $ROUTER2 dev $INTERFACE2 table 2" >> /etc/sysconfig/network-scripts/route-$INTERFACE1

echo "Network config changed successfully. Rebooting to make persistent changes"

