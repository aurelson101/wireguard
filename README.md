# Wireguard

Wireguard is generally very simple to set up and above all very efficient. So I copy my script for those who want a version without too much hassle.


# Files

**wireguard-install** : Usually works with ubuntu or debian (lazy for other distributions).
It creates an ipv4 and ipv6 subnet and creates the ufw firewall rules. Take care to edit the script before installation.

**create-user** : The one if asks for the user's name and detects if it already exists, it creates the appropriate configuration follow the wireguard server, offer to display the configuration or via qrcode. Adapt the script also follow your configuration.

## Wireguard install edit ?

From line ***# Configure WireGuard*** I advise you to leave the subnets by default, but modify the ips dns follow your dns.

From line ***# Create IPv4 and IPv6 subnets***  edit the routes and the firewall rule at the end follow your configuration.

## Wireguard Create User

From line ***# Get next free IP address for user (IPv4 and IPv6)***  edit this configuration if you have changed your ipv4 and ipv6 subnets.

## Proposal
Feel free to modify the file or another git branch if you wish as long as it works.