#!/bin/bash

# Define color codes
GREEN='\033[0;32m'
NC='\033[0m' # No Color

start_time=$(date +%s)

echo -e "${GREEN}========== Install dependencies ==========${NC}\n"

pkg update && pkg upgrade -y
pkg install -y \
    proot \
    proot-distro \
    pulseaudio \
    git \
    curl \
    wget \
    zsh \
    python

echo -e "${GREEN}===== Remove existing Ubuntu distro =====${NC}\n"

proot-distro remove ubuntu

echo -e "${GREEN}===== Install and setup proot distro =====${NC}\n"

# Set environment variable to potentially fix proot warnings
export PROOT_NO_SECCOMP=1

# Attempt to install Ubuntu, with error handling
if ! proot-distro install ubuntu; then
    echo "Failed to install Ubuntu. Trying alternative method..."
    proot-distro install ubuntu --override-alias ubuntu-lts
fi

# Check if Ubuntu was successfully installed
if ! proot-distro list | grep -q "ubuntu"; then
    echo "Failed to install Ubuntu. Exiting."
    exit 1
fi

# Login to Ubuntu and set up user, Zsh, and Oh My Zsh
proot-distro login ubuntu -- /bin/bash << EOF
set -e  # Exit on any error

# Basic system setup
apt update && apt upgrade -y
apt install -y zsh sudo curl wget git

# Create user and set up sudo
useradd -m -s /bin/zsh user
echo "user:password" | chpasswd
usermod -aG sudo user
echo "user ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Switch to the new user and set up Zsh
su - user << EOL
export SHELL=/bin/zsh
export TERM=xterm-256color

# Install Oh My Zsh
sh -c "\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-autosuggestions \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

# Configure Zsh
cat << 'ZSHRC' > ~/.zshrc
export ZSH="\$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions)
source \$ZSH/oh-my-zsh.sh
export SHELL=/bin/zsh
export TERM=xterm-256color
export PROOT_NO_SECCOMP=1
ZSHRC

# Source the new .zshrc
source ~/.zshrc
EOL

# Create a custom login script
cat << 'EOT' > /usr/local/bin/login-as-user
#!/bin/bash
if [ "\$(id -u)" -eq 0 ]; then
    exec su - user
else
    exec /bin/zsh -l
fi
EOT

chmod +x /usr/local/bin/login-as-user

# Modify proot-distro login command
sed -i 's|command="bash"|command="/usr/local/bin/login-as-user"|' /data/data/com.termux/files/usr/etc/proot-distro/ubuntu.sh

echo "User 'user' created successfully in Ubuntu environment with Zsh and Oh My Zsh."
echo "The system is now set up to automatically log in as 'user' when using 'proot-distro login ubuntu'."
EOF

echo -e "${GREEN}============== Finish ==============${NC}\n"

end_time=$(date +%s)

elapsed_time=$((end_time - start_time))

echo "Elapsed time: $elapsed_time seconds"
