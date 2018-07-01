#!/bin/bash
######################################################################################################
# This script will configure multiple IP addresses on the same NIC to work an AWS RHEL/Centos instance
# The additional IP addresses can be added via the console
######################################################################################################

# Start of user input
PRIVATEIP1=172.31.18.85/20
PRIVATEIP2=172.31.30.54/2
GATEWAY=172.31.16.1
DNS=172.31.0.2
IFNAME=eth0
CONNECTIONNAME="test"
# End of user input

if [[ $EUID != 0 ]]
then
        echo "ERROR. Need to have root privileges to run this script"
        exit 1
else
        echo "##############################################################################"
        echo "This script will configure a new network manager connection - $CONNECTIONNAME"
        echo "AWS by default creates a connection, but won't let an additional IP be added"
        echo "Once done the network interface - $IFNAME will have the following addresses"
        echo "$PRIVATEIP1 and $PRIVATEIP2"
        echo "##############################################################################"
	sleep 5
fi

nmcli connection delete $CONNECTIONNAME &>/dev/null
sleep 3 
nmcli connection add con-name $CONNECTIONNAME type ethernet ifname $IFNAME ipv4.address $PRIVATEIP1 ipv4.gateway $GATEWAY ipv4.dns $DNS ipv4.method manual autoconnect true
sleep 3
nmcli connection modify $CONNECTIONNAME +ipv4.addresses $PRIVATEIP2
systemctl restart network
nmcli connection up $CONNECTIONNAME

echo "#################################################################################################"
echo "Additional IP added"
sleep 1
echo "#################################################################################################"
ip -4 addr show
echo "#################################################################################################"

