#!/bin/bash

# Check if user is root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Check if /etc/fireguard exists, if not create it
if [ ! -d "/etc/fireguard" ]; then
  mkdir /etc/fireguard
fi

# Get username
read -p "Enter username: " USERNAME

# Check if username already exists
if [ -f "/etc/fireguard/$USERNAME.conf" ]; then
  echo "Username already exists"
  exit 1
fi

# Generate keys for user
wg genkey | tee /etc/fireguard/$USERNAME.priv | wg pubkey > /etc/fireguard/$USERNAME.pub

# Get server public key and endpoint
SERVER_PUBKEY=$(grep PublicKey /etc/wireguard/wg0.conf | awk '{print $3}')
# Get username
read -p "Enter hostname vpn: " SERVER_ENDPOINT

# Get next free IP address for user (IPv4 and IPv6)
read IP < <(echo $(grep AllowedIPs /etc/wireguard/wg0.conf | grep -v : | awk '{print $3}' | cut -d "." -f 4 | sort -n | tail -1) + 1 | bc)
IPV4="10.0.0.$IP"
read IP < <(echo $(grep AllowedIPs /etc/wireguard/wg0.conf | grep : | awk '{print $3}' | cut -d ":" -f 8 | sort -n | tail -1) + 1 | bc)
IPV6="fd86:ea04:1115::$(printf '%x\n' $IP)"

# Create user config file
echo "[Interface]
PrivateKey = $(cat /etc/fireguard/$USERNAME.priv)
Address = $IPV4/24, $IPV6/64
DNS = 192.168.1.1, 2001:2356:5588::123

[Peer]
PublicKey = $SERVER_PUBKEY
Endpoint = $SERVER_ENDPOINT:51820
AllowedIPs = 0.0.0.0/0, ::/0" > /etc/fireguard/$USERNAME.conf

# Add user to server config file
echo "
[Peer]
PublicKey = $(cat /etc/fireguard/$USERNAME.pub)
AllowedIPs = $IPV4/32, $IPV6/128" >> /etc/wireguard/wg0.conf

# Restart WireGuard to apply changes
wg-quick down wg0
wg-quick up wg0

# Ask user if they want to display config as text or QR code
read -p "Display config as (t)ext or (q)r code? " CHOICE

if [ "$CHOICE" == "t" ]; then
  cat /etc/fireguard/$USERNAME.conf
elif [ "$CHOICE" == "q" ]; then
  qrencode -t ansiutf8 < /etc/fireguard/$USERNAME.conf
else
  echo "Invalid choice"
fi

