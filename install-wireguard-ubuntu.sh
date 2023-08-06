#!/bin/bash

# Check if user is root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

function checkVirt() {
	if [ "$(systemd-detect-virt)" == "openvz" ]; then
		echo "OpenVZ is not supported"
		exit 1
	fi

	if [ "$(systemd-detect-virt)" == "lxc" ]; then
		echo "LXC is not supported (yet)."
		echo "WireGuard can technically run in an LXC container,"
		echo "but the kernel module has to be installed on the host,"
		echo "the container has to be run with some specific parameters"
		echo "and only the tools need to be installed in the container."
		exit 1
	fi
}

# Check if the system is running Debian or Ubuntu
if [ -f /etc/debian_version ]; then
    echo "The system is running Debian or Ubuntu."
else
    echo "The system is not running Debian or Ubuntu, stopping script."
    exit 1
fi

# Detect primary Ethernet port
ETH=$(ip route | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//")
echo "Primary Ethernet port: $ETH"

# Detect public IPv4 and IPv6 addresses
IPV4=$(curl -4 ifconfig.co)
IPV6=$(curl -6 ifconfig.co)
echo "Public IPv4 address: $IPV4"
echo "Public IPv6 address: $IPV6"

# Install WireGuard and UFW
apt-get update
apt-get install -y wireguard ufw qrencode

# Enable forwarding
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf
sysctl -p

# Generate WireGuard key
umask 077
wg genkey | tee /etc/wireguard/privatekey | wg pubkey | tee /etc/wireguard/publickey
privkey=$(cat /etc/wireguard/privatekey)
pubkey=$(cat /etc/wireguard/pubblickey)

# Create Subnet ipv4 and ipv6
echo "Please choose an option:"
echo "1. Manually enter IPv4 and IPv6 subnets"
echo "2. Automatically generate IPv4 and IPv6 subnets"
read choice

if [ "$choice" == "1" ]; then
    echo "Please enter the IPv4 subnet (e.g. 10.20.30.1):"
    read ipv4_subnet
    echo "Please enter the IPv6 subnet (e.g. fd86:1111:2222::1):"
    read ipv6_subnet
elif [ "$choice" == "2" ]; then
    ipv4_subnet="10.10.10.1"
    ipv6_subnet="fd86:ea04:1115::1"
else
    echo "Invalid choice, exiting."
    exit 1
fi

echo - Show Subnet configuration
echo $ipv4_subnet
echo $ipv6_subnet

# Select port udp wireguard
echo "Please choose an option:"
echo "1. Manually enter port wireguard"
echo "2. Default port (e.g. 51820)"
read choice

if [ "$choice" == "1" ]; then
    echo "Manually enter port wireguard (e.g. 1194):"
    read portw
elif [ "$choice" == "2" ]; then
    portw="51820"
else
    echo "Invalid choice, exiting."
    exit 1
fi

echo - Wireguard port is 
echo $portw

# Configure WireGuard
tee /etc/wireguard/wg0.conf <<EOL
[Interface]
PrivateKey = $privkey
Address = $ipv4_subnet/24, $ipv6_subnet/64
ListenPort = $portw
#exemple iptables conf if ufw don't work :
#PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $ETH -j MASQUERADE
#PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $ETH -j MASQUERADE
SaveConfig = true
EOL

# Start WireGuard
wg-quick up wg0

# Enable UFW
ufw --force enable

# Allow SSH, DNS, NTP, HTTP, and HTTPS for IPv4 and IPv6
ufw default deny incoming
ufw default allow outgoing
# Allow forwarding
ufw default allow routed
ufw allow ssh
ufw allow 53/tcp
ufw allow 53/udp
ufw allow 123/udp
ufw allow http
ufw allow https
ufw allow $portw/udp # WireGuard
# Enable NAT for outgoing traffic on eth0
sed -i '1s/^/*nat\n:POSTROUTING ACCEPT [0:0]\n/' /etc/ufw/before.rules
echo "-A POSTROUTING -o $ETH -j MASQUERADE" >> /etc/ufw/before.rules
echo "COMMIT" >> /etc/ufw/before.rules
ufw reload

#exemple conf route and ufw subnet local
# Create IPv4 and IPv6 subnets
#ip route add 192.168.0.0/16 dev wg0
#ip -6 route add fd86:ea04:1115::/48 dev wg0

# Allow access to subnet 192.168.0.0/16
#ufw allow from 192.168.0.0/16 to any port 22 proto tcp
