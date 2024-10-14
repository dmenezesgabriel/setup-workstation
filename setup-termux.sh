#!/bin/bash

# Define color codes
GREEN='\033[0;32m'
NC='\033[0m' # No Color

start_time=$(date +%s)

echo -e "${GREEN}========== Install dependencies ==========${NC}\n"

pkg update && pkg upgrade -y
pkg install -y \
    x11-repo \
    proot \
    proot-distro \
    tur-repo \
    pulseaudio \
    openssh \
    git \
    curl \
    wget \
    zsh \
    tmux \
    vim \
    build-essential \
    python \
    python-pip \
    nodejs-lts

echo -e "${GREEN}======= Create virtual environment =======${NC}\n"

rm -rf ~/environments/general && \
python -m venv --system-site-packages ~/environments/general && \
echo "source ~/environments/general/bin/activate" >> ~/.bashrc && \
source ~/environments/general/bin/activate

echo -e "${GREEN}===== Remove existing Ubuntu distro =====${NC}\n"

proot-distro remove ubuntu

echo -e "${GREEN}===== Install and setup proot distro =====${NC}\n"

proot-distro install ubuntu

# Login to Ubuntu and set up user, Zsh, and Oh My Zsh
proot-distro login ubuntu -- /bin/bash << EOF
apt update && apt upgrade -y
apt install -y zsh sudo curl wget git

useradd -m -s /bin/zsh user
echo "user:password" | chpasswd
usermod -aG sudo user

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
ZSHRC

# Source the new .zshrc
source ~/.zshrc
EOL

# Create a custom login script
cat << 'EOT' > /usr/local/bin/login-as-user
#!/bin/zsh
if [ "\$(id -u)" -eq 0 ]; then
    exec su - user
else
    exec /bin/zsh -l
fi
EOT

chmod +x /usr/local/bin/login-as-user

# Modify proot-distro login command
sed -i 's|command="bash"|command="login-as-user"|' /data/data/com.termux/files/usr/etc/proot-distro/ubuntu.sh

echo "User 'user' created successfully in Ubuntu environment with Zsh and Oh My Zsh."
echo "Note: The user 'user' has been added to the sudo group and will need to enter their password when using sudo."
echo "The system is now set up to automatically log in as 'user' when using 'proot-distro login ubuntu'."
EOF

echo -e "${GREEN}============== Finish ==============${NC}\n"

end_time=$(date +%s)

elapsed_time=$((end_time - start_time))

echo "Elapsed time: $elapsed_time seconds"
