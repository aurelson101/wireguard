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
wg genkey | tee privatekey | wg pubkey > publickey

# Configure WireGuard
echo "[Interface]
PrivateKey = $(cat privatekey)
Address = 10.0.0.1/24, fd86:ea04:1115::1/64
ListenPort = 51820
DNS = 192.168.1.1, 2001:2356:5588::123" > /etc/wireguard/wg0.conf

# exemple public peer don't forget to edit it
#[Peer]
#PublicKey = <PEER_PUBLIC_KEY>
#AllowedIPs = 10.0.0.2/32, fd86:ea04:1115::2/128

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
ufw allow 51820/udp # WireGuard
# Enable NAT for outgoing traffic on eth0
sed -i '1s/^/*nat\n:POSTROUTING ACCEPT [0:0]\n/' /etc/ufw/before.rules
echo "-A POSTROUTING -o $ETH -j MASQUERADE" >> /etc/ufw/before.rules
echo "COMMIT" >> /etc/ufw/before.rules
ufw reload


# Create IPv4 and IPv6 subnets
ip route add 192.168.0.0/16 dev wg0
ip -6 route add fd86:ea04:1115::/48 dev wg0

# Allow access to subnet 192.168.0.0/16
ufw allow from 192.168.0.0/16 to any port 22 proto tcp
