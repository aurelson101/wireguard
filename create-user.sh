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

read -p "Enter username: " USERNAME

# Check if username already exists
if [ -f "/etc/fireguard/$USERNAME.conf" ]; then
  echo "Username already exists"
  exit 1
fi

# Generate keys for user
wg genkey | tee /etc/wireguard/$USERNAME-priv | wg pubkey | tee /etc/wireguard/$USERNAME-pub

echo - privatekey $USERNAME
USERNAMEpriv=$(cat /etc/wireguard/$USERNAME-priv)
USERNAMEpub=$(cat /etc/wireguard/$USERNAME-pub)
echo $USERNAMEpriv

echo - server pubkey
SERVER_PUBKEY=$(cat /etc/wireguard/publickey)
echo - $SERVER_PUBKEY

# Get username
read -p "Enter hostname vpn: " SERVER_ENDPOINT

echo - server endpoint is $SERVER_ENDPOINT

# Detect IPv4 and IPv6 from wg0
ipv4=$(ip -4 addr show wg0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
ipv6=$(ip -6 addr show wg0 | grep -oP '(?<=inet6\s)[\da-f:]+')

# Check if IP addresses have been detected
if [[ -z $ipv4 ]] && [[ -z $ipv6 ]]; then
    echo "Aucune adresse IP détectée pour l'interface wg0"
    exit 1
fi

# View detected IP address
echo "Adress IPv4 from wg0: $ipv4"
echo "Adress IPv6 from wg0: $ipv6"


# Prompt for the IPv4 subnet
read -p "Enter the IPv4 subnet (ex 10.10.10.xxx): " ipv4_subnet
read -p "Enter the IPv6 subnet (fd86:ea04:1115::xxx): " ipv6_subnet
echo "Adding IPv4 subnet: $ipv4_subnet"
echo "Adding IPv6 subnet: $ipv6_subnet"


#Get DNS selection :
echo "Wireguard DNS choice:"
echo "1: Add IPv4 and IPv6 DNS manually"
echo "2: Select DNS provider by number"
read -p "Enter your choice: " choice

if [ "$choice" == "1" ]; then
    read -p "Enter IPv4 DNS: " dns4
    read -p "Enter IPv6 DNS: " dns6
    echo "IPv4 DNS set to $dns4"
    echo "IPv6 DNS set to $dns6"
else
    echo "Select DNS provider:"
    echo "1: Google (IPv4 and IPv6)"
    echo "2: Cloudflare (IPv4 and IPv6)"
    echo "3: Quad9 (IPv4 or IPv6)"
    echo "4: Adguard (IPv4 or IPv6)"
    read -p "Enter your choice: " dns_choice
    case $dns_choice in
        1)
            dns4="8.8.8.8"
            dns6="2001:4860:4860::8888"
            ;;
        2)
            dns4="1.1.1.1"
            dns6="2606:4700:4700::1111"
            ;;
        3)
            dns4="9.9.9.9"
            dns6="2620:fe::fe"
            ;;
        4)
            dns4="176.103.130.130"
            dns6="2a00:5a60::ad1:0ff"
            ;;
        *)
            echo "Invalid choice"
            exit 1
            ;;
    esac
    echo "IPv4 DNS set to $dns4"
    echo "IPv6 DNS set to $dns6"
fi

# Create user config file
tee /etc/wireguard/$USERNAME.conf <<EOL
[Interface]
PrivateKey = $(cat /etc/wireguard/$USERNAME-priv)
Address = $ipv4_subnet/32, $ipv6_subnet/128
DNS = $dns4, $dns6

[Peer]
PublicKey = $SERVER_PUBKEY
AllowedIPs = 0.0.0.0/0, ::/0"
Endpoint = $SERVER_ENDPOINT:51820
Persistentkeepalive = 21
EOL

# stop WireGuard
wg-quick down wg0
# Content to append
content="

[peer]
PublicKey = $USERNAMEpub
AllowedIPs = $ipv4_subnet/32"

# Append the content to the file
echo "$content" | sudo tee -a /etc/wireguard/wg0.conf

# Restart WireGuard to apply changes
wg-quick up wg0

# Ask user if they want to display config as text or QR code
read -p "Display config as (t)ext or (q)r code? " CHOICE

if [ "$CHOICE" == "t" ]; then
  cat /etc/wireguard/$USERNAME.conf
elif [ "$CHOICE" == "q" ]; then
  qrencode -t ansiutf8 < /etc/wireguard/$USERNAME.conf
else
  echo "Invalid choice"
fi

