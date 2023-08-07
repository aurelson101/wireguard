#!/bin/bash

# Check if the user is connected to root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

# Check if ufw is installed
if ! command -v ufw &> /dev/null; then
    echo "ufw is not installed. Installing ufw..."
    apt-get update
    apt-get install ufw -y
fi
# Detect primary Ethernet port
ETH=$(ip route | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//")
echo "Primary Ethernet port: $ETH"

# Reset ufw rules
ufw --force reset

# Set default policies to deny all incoming and outgoing traffic
ufw default deny incoming
ufw default deny outgoing

# Allow loopback traffic (IPv4 and IPv6)
ufw allow in on lo
ufw allow out on lo

# Allow default port
ufw allow in 80/tcp
ufw allow out 80/tcp
ufw allow in 443/tcp
ufw allow out 443/tcp
ufw allow in 22/tcp
ufw allow out 22/tcp
ufw allow in 51820/udp # WireGuard port
ufw allow out 51820/udp # WireGuard port
ufw allow in 53/udp # DNS port (tcp and udp)
ufw allow out 53/udp # DNS port (tcp and udp)
ufw allow in 123/udp # NTP port (udp)
ufw allow out 123/udp # NTP port (udp)


# Select subnet traffic

echo "Please select an option:"
echo "1: Select allow subnet IPv4 and IPv6 manually"
echo "2: Add automatic all full traffic"

read -p "Enter your choice: " choice

case $choice in
    1)
        read -p "Enter the IPv4 subnet (ex: 192.168.10.0/24): " ipv4_subnet
        read -p "Enter the IPv6 subnet (ex: fde::0/64): " ipv6_subnet
        ufw allow in on eth0 from $ipv4_subnet comment 'Allow subnet IPv4'
        ufw allow in on eth0 from $ipv6_subnet comment 'Allow subnet IPv6'
        ;;
    2)
        # Allow all IPv4 traffic 
        ufw route allow in on $ETH out on wg0 from 0.0.0.0/0 to 0.0.0.0/0 
        ufw route allow out on $ETH in on wg0 from 0.0.0.0/0 to 0.0.0.0/0 
        # Allow all IPv6 traffic 
        ufw route allow in on $ETH out on wg0 from ::/0 to ::/0 
        ufw route allow out on $ETH in on wg0 from ::/0 to ::/0 
        ;;
    *)
        echo "Invalid choice"
        ;;
esac

# Allow all traffic from WireGuard interface (replace wg0 with your WireGuard interface name)
ufw allow in on wg0 
ufw allow out on wg0 

# Add masquerade rule for WireGuard interface (replace wg0 with your WireGuard interface name)
#echo "### tuple ### allow any any 0.0.0.0/0 any 0.0.0.0/0 in on wg0" >> /etc/ufw/before.rules
#echo "-A POSTROUTING -s 10.200.200.0/24 -o eth0 -j MASQUERADE" >> /etc/ufw/before.rules
sed -i '/^COMMIT$/i *nat\n:POSTROUTING ACCEPT [0:0]\n-A POSTROUTING -o $ETH -j MASQUERADE\n' /etc/ufw/before.rules

# Add NAT and IP masquerade rules to /etc/ufw/before6.rules before the COMMIT line
sed -i '/^COMMIT$/i *nat\n:POSTROUTING ACCEPT [0:0]\n-A POSTROUTING -o $ETH -j MASQUERADE\n' /etc/ufw/before6.rules

echo "NAT and IP masquerade rules added successfully"
# Enable ufw
ufw --force enable

echo "UFW configured successfully"
