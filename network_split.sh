#!/bin/bash
####################################################################################################################
# This script will let the traffic be split b/w multiple network interfaces as per diff requirements
####################################################################################################################
# Start of user inputs
####################################################################################################################
INTERFACE1="eth0"
INTERFACE2="eth1"
IP2=
SUBNET2=
ROUTER2=
DNS2=
SSHPORT="22"
CREATE_NMCLI_CONNECTION="yes" # if the 2nd interface doesnt already have a nmcli connection set up
CONNECTION_NAME2="test"
COMMON_FILE="https://raw.githubusercontent.com/sgupt9999/common/master/common_fn" # Location of the common function
LOG_FILE="/tmp/network_split.log"
####################################################################################################################
# End of user inputs
####################################################################################################################

yum install wget -y -q
rm -rf common_fn
wget $COMMON_FILE
source ./common_fn
rm -rf $LOG_FILE
exec 5>$LOG_FILE


# Create a new connection if needed
if [[ $CREATE_NMCLI_CONNECTION == "yes" ]]
then
	MESSAGE="Creating a new network manager connection"
	print_msg_start
	nmcli connnection delete $CONNECTION_NAME2
	nmci connection add con-name $CONNECTION_NAME2 type ethernet ifname $INTERFACE2 ipv4.address $INTERFACE2\$SUBNET2 /
	ipv4.dns $DNS2 ipv4.gateway $ROUTER2 autoconect true ipv4.method manual
	nmcli connection up $CONNECTION_NAME2
	print_msg_done
fi

exit 1


echo "0" > /proc/sys/net/ipv4/conf/all/rp_filter
echo "0" > /proc/sys/net/ipv4/conf/eth0/rp_filter
echo "0" > /proc/sys/net/ipv4/conf/tun0/rp_filter

iptables -X
iptables -F
iptables -X -t nat
iptables -F -t nat
iptables -X -t mangle
iptables -F -t mangle

iptables -S
iptables -S -t nat
iptables -S -t mangle

#iptables -t mangle -D OUTPUT -o eth0 -p tcp -m tcp --dport 80 -j MARK --set-mark 99
#iptables -t mangle -A OUTPUT -o eth0 -p tcp -m tcp --dport 80 -j MARK --set-mark 99
iptables -t mangle -D OUTPUT -o eth0 -p tcp -m tcp ! --sport 22 -j MARK --set-mark 99
iptables -t mangle -A OUTPUT -o eth0 -p tcp -m tcp ! --sport 22 -j MARK --set-mark 99

iptables -t nat -D POSTROUTING -j MASQUERADE
iptables -t nat -A POSTROUTING -j MASQUERADE

ip route delete default via 10.8.0.1 dev tun0 tab 2
ip route add default via 10.8.0.1 dev tun0 tab 2

ip rule delete priority 200
ip rule delete priority 300
ip rule add fwmark 99 table 2 priority 200
ip rule add from 10.8.0.2/32 table 2 priority 300

ip route flush cache

