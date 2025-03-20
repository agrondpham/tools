#!/bin/bash

# Enable SSH root login
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Restart SSH service
if systemctl status ssh >/dev/null 2>&1; then
    systemctl restart ssh
elif systemctl status sshd >/dev/null 2>&1; then
    systemctl restart sshd
else
    echo "SSH service not found!"
    exit 1
fi

echo "Root SSH login enabled!"