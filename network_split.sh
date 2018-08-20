#!/bin/bash
####################################################################################################################
# This script will let the traffic be split b/w multiple network interfaces as per diff requirements
####################################################################################################################
# Start of user inputs
####################################################################################################################
INTERFACE1="eth0"
INTERFACE2="eth1"

IP1=172.31.6.245
SUBNET1=20
ROUTER1=172.31.0.1
DNS1=172.31.0.2

IP2=172.31.7.91
SUBNET2=20
ROUTER2=172.31.0.1
DNS2=172.31.0.2

CREATE_NMCLI_CONNECTION="yes" # if the 2nd interface doesnt already have a nmcli connection set up
CONNECTION_NAME2="test"
COMMON_FILE="https://raw.githubusercontent.com/sgupt9999/common/master/common_fn" # Location of the common function
LOG_FILE="/tmp/network_split.log"
REQUIREMENT="1" # 1. The 1st interface is only allowed for SSH. All other outgoing is from the 2nd interface
SSHPORT="22"

SHOW_SETTINGS="yes"

####################################################################################################################
# End of user inputs
####################################################################################################################

rm -rf $LOG_FILE
exec 5>$LOG_FILE

if [[ $EUID != "0" ]]
then
	echo
	echo "##########################################################"
	echo "ERROR. You need to have root privileges to run this script"
	echo "##########################################################"
	echo >&5
	echo "##########################################################" >&5
	echo "ERROR. You need to have root privileges to run this script" >&5
	echo "##########################################################" >&5
	exit 1
fi

yum install wget -y -q
rm -rf common_fn
wget $COMMON_FILE
source ./common_fn

# Create a new connection if needed
if [[ $CREATE_NMCLI_CONNECTION == "yes" ]]
then
	MESSAGE="Creating a new network manager connection"
	print_msg_start
	nmcli connection delete $CONNECTION_NAME2 >&5 2>&5
	nmcli connection add con-name $CONNECTION_NAME2 type ethernet ifname $INTERFACE2 ipv4.address $IP2/$SUBNET2 \
	ipv4.dns $DNS2 ipv4.gateway $ROUTER2 autoconnect true ipv4.method manual >&5 2>&5
	nmcli connection up $CONNECTION_NAME2 >&5 2>&5
	print_msg_done
fi

# This is not a recommended security setting, but cannot make it work w/o the no source validation
echo "0" > /proc/sys/net/ipv4/conf/all/rp_filter
echo "0" > /proc/sys/net/ipv4/conf/$INTERFACE1/rp_filter
echo "0" > /proc/sys/net/ipv4/conf/$INTERFACE2/rp_filter

# Setting up iptables
MESSAGE="Setting up iptables"
print_msg_start

iptables -X
iptables -F
iptables -X -t nat
iptables -F -t nat
iptables -X -t mangle
iptables -F -t mangle

case $REQUIREMENT in
	1)
		#iptables -t mangle -D OUTPUT -o eth0 -p tcp -m tcp --dport 80 -j MARK --set-mark 99
		#iptables -t mangle -A OUTPUT -o eth0 -p tcp -m tcp --dport 80 -j MARK --set-mark 99
		# Mark any packets not coming from port 22
		iptables -t mangle -D OUTPUT -o $INTERFACE1 -p tcp -m tcp ! --sport $SSHPORT -j MARK --set-mark 99 >&5 2>&5
		iptables -t mangle -A OUTPUT -o $INTERFACE1 -p tcp -m tcp ! --sport $SSHPORT -j MARK --set-mark 99 >&5 2>&5
		# Mark all UDP packets
		iptables -t mangle -D OUTPUT -o $INTERFACE1 -p udp -j MARK --set-mark 99 >&5 2>&5
		iptables -t mangle -A OUTPUT -o $INTERFACE1 -p udp -j MARK --set-mark 99 >&5 2>&5
		# Drop any connections to the 2nd interface on the ssh port
		iptables -D INPUT -i $INTERFACE2 -p tcp --dport $SSHPORT -j DROP >&5 2>&5
		iptables -A INPUT -i $INTERFACE2 -p tcp --dport $SSHPORT -j DROP >&5 2>&5

		iptables -t nat -D POSTROUTING -j MASQUERADE >&5 2>&5
		iptables -t nat -A POSTROUTING -j MASQUERADE >&5 2>&5
		
		# Create a new routing table for traffic via the 2nd interface
		ip route delete default via $ROUTER2 dev $INTERFACE2 tab 2 >&5 2>&5
		ip route add default via $ROUTER2 dev $INTERFACE2 tab 2 >&5 2>&5

		
		# Any packet qwth the mark needs to look at the 2nd routing table
		ip rule delete priority 200 >&5 2>&5
		ip rule delete priority 300 >&5 2>&5
		ip rule add fwmark 99 table 2 priority 200 >&5 2>&5
		ip rule add from $IP2/32 table 2 priority 300 >&5 2>&5

		ip route flush cache
esac

print_msg_done

# Show current settings
if [[ $SHOW_SETTINGS == "yes" ]]
then
	MESSAGE="Showing current settings"
	print_msg_start
	echo "ip route show"
	ip route show
	echo
	echo "ip route show tab 1"
	ip route show tab 1
	echo
	echo "ip route show tab 2"
	ip route show tab 2 
	echo
	echo "ip rule show"
	ip rule show
	echo
	echo "iptables -S -t filter"
	iptables -S -t filter
	echo
	echo "iptables -S -t nat"
	iptables -S -t nat
	echo
	echo "iptables -S -t mangle"
	iptables -S -t mangle
	echo
	
	print_msg_done
fi
	

