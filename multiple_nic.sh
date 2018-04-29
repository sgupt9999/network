#!/bin/bash
# On AWS With multiple network cards with the default route tables the outbound public traffic keeps going out via the default interface
# This can be tested by running tcpdump on default interface and then sending a ping to the 2nd interface
# The second address will try to send return traffic via the 1st interface
# To fix this need to create a rule to direct traffic from second address through the 2nd network interface card
# Also creating a systemd service that will create the rules and routes on boot and also
# adding to the network.service so the script is also called when starting network


# User inputs
INTERFACE1="eth0"
INTERFACE2="eth1"
IP1=10.0.0.70/32
IP2=10.0.5.179/32
ROUTER1=10.0.0.1
ROUTER2=10.0.5.1
# End of user inputs

if [[ $EUID != "0" ]]
then
	echo "ERROR. You need root privileges to run this script"
	exit 1
fi


# Create the file that will be called by the systemd service
rm -rf /usr/local/src/routes.sh
cat << EOF > /usr/local/src/routes.sh
#!/bin/bash
# Adding the routes for the 2nd network interface to work correctly

ip route flush tab 1 >/dev/null 2>&1
ip route flush tab 2 >/dev/null 2>&1
ip rule del priority 500 >/dev/null 2>&1
ip rule del priority 600 >/dev/null 2>&1

ip route add default via $ROUTER1 dev $INTERFACE1 tab 1
ip route add default via $ROUTER2 dev $INTERFACE2 tab 2
ip rule add from $IP1 tab 1 priority 500
ip rule add from $IP2 tab 2 priority 600
EOF
chmod a+x /usr/local/src/routes.sh
# End of file with new routes and rules


# Create a new systemd service
rm -rf /etc/systemd/system/multiple-nic.service
cat << EOF > /etc/systemd/system/multiple-nic.service
[Unit]
Description=Configure routing for multiple network interface cards
After=network-online.target network.service

[Service]
ExecStart=/usr/local/src/routes.sh

[Install]
WantedBy=network-online.target network.service
EOF
# End of new systemd service
echo "New systemd service - multiple-nic.service created"

systemctl enable multiple-nic.service

systemctl restart network
echo "Network restarted successfully"
