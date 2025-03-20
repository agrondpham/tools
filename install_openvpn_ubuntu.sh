#!/bin/bash

# Update system
apt update && apt upgrade -y

# Install OpenVPN and Easy-RSA
apt install -y openvpn easy-rsa

# Set up Easy-RSA
make-cadir ~/openvpn-ca
cd ~/openvpn-ca

# Configure vars
cat > vars <<EOF
set_var EASYRSA_ALGO "rsa"
set_var EASYRSA_KEY_SIZE 2048
set_var EASYRSA_CA_EXPIRE 3650
set_var EASYRSA_CERT_EXPIRE 3650
set_var EASYRSA_REQ_COUNTRY "US"
set_var EASYRSA_REQ_PROVINCE "CA"
set_var EASYRSA_REQ_CITY "SanFrancisco"
set_var EASYRSA_REQ_ORG "MyOrg"
set_var EASYRSA_REQ_EMAIL "admin@example.com"
set_var EASYRSA_REQ_OU "MyUnit"
set_var EASYRSA_BATCH "yes"
EOF

# Build the CA
./easyrsa init-pki
./easyrsa build-ca nopass

# Generate server certificate and key
./easyrsa gen-req server nopass
./easyrsa sign-req server server

# Generate Diffie-Hellman parameters
./easyrsa gen-dh

# Copy server files
cp pki/ca.crt pki/private/server.key pki/issued/server.crt pki/dh.pem /etc/openvpn/server/

# Create server config
cat > /etc/openvpn/server/server.conf <<EOF
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
keepalive 10 120
tls-auth ta.key 0
cipher AES-256-CBC
persist-key
persist-tun
status openvpn-status.log
verb 3
EOF

# Enable IP forwarding
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p

# Start OpenVPN
systemctl start openvpn-server@server
systemctl enable openvpn-server@server

# Create client keys
for client in client1 client2; do
    ./easyrsa gen-req $client nopass
    ./easyrsa sign-req client $client
    mkdir -p ~/openvpn-clients/$client
    cp pki/ca.crt pki/issued/$client.crt pki/private/$client.key ~/openvpn-clients/$client/

    # Generate client config
    cat > ~/openvpn-clients/$client/$client.ovpn <<EOF
client
dev tun
proto udp
remote YOUR_SERVER_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-CBC
verb 3
<ca>
$(cat ~/openvpn-ca/pki/ca.crt)
</ca>
<cert>
$(cat ~/openvpn-ca/pki/issued/$client.crt)
</cert>
<key>
$(cat ~/openvpn-ca/pki/private/$client.key)
</key>
EOF

done

echo "OpenVPN installation and client setup completed. Client configs are in ~/openvpn-clients/"
