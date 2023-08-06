
# Wireguard

Wireguard is generally very simple to set up and above all very efficient. So I copy my script for those who want a version without too much hassle.


# Files

**wireguard-install** : Detect if you are not root, and detect if you are using Debian or Ubuntu and Detect your public IPV4 and IPV6. Also detect the ethernet port to use by default and install wireguard and qrcode before proceeding to the next steps.

**create-user** : The one if asks for the user's name and detects if it already exists, it creates the appropriate configuration follow the wireguard server, offer to display the configuration or via qrcode, see the procedure below.

#  Wireguard install ask ?

### First step :
Indicates if you want to add a subnet (example 10.10.10.1 or fde:1000:1000::1) manually or automatically the subnets that I added. The 2 subnets will be used for the VPN network.

 1. Manually enter IPv4 and IPv6 subnets
 2. Automatically generate IPv4 and IPv6 subnets

### Second step : 
By default the wireguard port is 51820 if you want to change select 1.
      
1. Manually enter port wireguard
2. Default port (e.g. 51820)

#  Wireguard route

Example if you need to add routes in an experimental way :
ip route add 192.168.0.0/16 dev wg0
ip -6 route add fd86:ea04:1115::/48 dev wg0

Exemple firewall rule:
Allow access ssh to subnet 192.168.0.0/16 :
iptables -A INPUT -s 192.168.0.0/16 -p tcp --dport 22 -j ACCEPT

#  Wireguard User ask ?
### First step :
indicates the name of your vpn client (ex: aurelien) and it will display your public and private key and server public key :

 1. Enter username:
 
### Second step : 
Add hostname **(recommend)** as example: vpn.example.com or vpnlab.ddns.net
      
1. Enter hostname vpn :

### Third step : 
This step asks to add an IPV4 and IPV6 dns, Manually or choose the default DNS in option 2 :
   
1. Add IPv4 and IPv6 DNS manually
2. Select DNS provider by number 
 - 1: Google (IPv4 and IPv6)
 - 2: Cloudflare (IPv4 and IPv6)
 - 3: Quad9 (IPv4 or IPv6)
 - 4: Adguard (IPv4 or IPv6)

### Fourth step : 
Proposes to display the configuration via text so only aper you the word **T** or via **QRCODE** via the word **Q**. 
Otherwise retrieve the user configuration in **/etc/wireguard/USERNAME.conf**.
      
1. Display config as (t)ext or (q)r code? t


## Proposal
Feel free to modify the file or another git branch if you wish as long as it works.