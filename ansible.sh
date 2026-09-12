#!/bin/bash

PUB_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM1RbH5sSaP7cpfDJXl3nH4TD59F5j0/B4JMt+mgaNJl semaphore-automation"

# 1. OS Detection & Dependency Install
if [ -f /usr/bin/apk ]; then
    echo 'Detected Alpine Linux'
    apk add --no-cache sudo shadow openssh-sftp-server openssh
    SHELL_BIN='/bin/sh'
    SSH_SERVICE='sshd'
elif [ -f /usr/bin/apt ]; then
    echo 'Detected Debian/Ubuntu'
    apt-get update && apt-get install -y sudo openssh-server
    SHELL_BIN='/bin/bash'
    SSH_SERVICE='ssh'
else
    echo 'Unknown OS, attempting generic setup...'
    SHELL_BIN='/bin/sh'
    SSH_SERVICE='sshd'
fi

# 2. User Creation & Account Unlocking
if ! id -u ansible >/dev/null 2>&1; then
    useradd -m -s ${SHELL_BIN} ansible
fi
# Ensure account is not locked (Common Alpine issue)
if [ -f /etc/shadow ]; then
    passwd -u ansible 2>/dev/null
fi

# 3. SSH Directory & Key Setup
mkdir -p /home/ansible/.ssh

# 4. SSH StrictModes Fix (Crucial for Alpine/Hardened templates)
# Home dir must NOT be group-writable
chown ansible:ansible /home/ansible
chmod 755 /home/ansible

# Check if key exists, otherwise append
if ! grep -q $PUB_KEY /home/ansible/.ssh/authorized_keys 2>/dev/null; then
    echo $PUB_KEY >> /home/ansible/.ssh/authorized_keys
fi

# Set strict perms on the .ssh folder itself
chown -R ansible:ansible /home/ansible/.ssh
chmod 700 /home/ansible/.ssh
chmod 600 /home/ansible/.ssh/authorized_keys

# 5. Sudoers Configuration
mkdir -p /etc/sudoers.d
echo 'ansible ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ansible
chmod 440 /etc/sudoers.d/ansible

# 6. Force SSHD to allow PubKey and use correct keys file
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#AuthorizedKeysFile/AuthorizedKeysFile/' /etc/ssh/sshd_config

# 7. Restart SSH service to apply changes
if [ -f /etc/init.d/${SSH_SERVICE} ]; then
    /etc/init.d/${SSH_SERVICE} restart
elif command -v systemctl >/dev/null 2>&1; then
    systemctl restart ${SSH_SERVICE}
fi