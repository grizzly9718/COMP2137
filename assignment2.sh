#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# 1. Configure Network
echo "Configuring Network..."
cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ens3:
      addresses:
        - 192.168.16.21/24
EOF
netplan apply

# Update /etc/hosts
echo "Updating /etc/hosts..."
sed -i '/server1/d' /etc/hosts  # Remove any old entries for server1
echo "192.168.16.21 server1" >> /etc/hosts

# 2. Install Software
echo "Installing Apache2 and Squid..."
apt update
apt install -y apache2 squid
systemctl enable --now apache2 squid

# 3. Create Users and SSH Keys
echo "Creating User Accounts..."
users=("dennis" "aubrey" "captain" "snibbles" "brownie" 
       "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")

for user in "${users[@]}"; do
    if ! id "$user" &>/dev/null; then
        useradd -m -s /bin/bash "$user"
        echo "$user created."

        # Generate SSH keys for the user if they don't exist
        su - "$user" -c "ssh-keygen -t rsa -N '' -f ~/.ssh/id_rsa"
        su - "$user" -c "ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519"

        # Combine public keys into authorized_keys file 
        cat "/home/$user/.ssh/id_rsa.pub" "/home/$user/.ssh/id_ed25519.pub" > "/home/$user/.ssh/authorized_keys"

        # Add to sudo group if user is dennis and add specific public key
        if [ "$user" == "dennis" ]; then
            usermod -aG sudo "$user"
            echo "Added $user to sudo group."
            echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm" >> "/home/$user/.ssh/authorized_keys"
        fi
    else
        echo "$user already exists."
    fi
done

echo "Configuration complete!"

