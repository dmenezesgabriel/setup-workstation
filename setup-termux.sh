#!/bin/bash

# Define color codes
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to create centered separator
create_separator() {
    local text="$1"
    local total_length=40
    local text_length=${#text}
    local padding=$(( (total_length - text_length) / 2 ))
    local separator=$(printf '%*s' "$padding" | tr ' ' '=')
    echo -e "${GREEN}${separator} ${text} ${separator}${NC}\n"
}

start_time=$(date +%s)

create_separator "Install dependencies"

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

create_separator "Create virtual environment"

rm -rf ~/environments/general && \
python -m venv --system-site-packages ~/environments/general && \
echo "source ~/environments/general/bin/activate" >> ~/.bashrc && \
source ~/environments/general/bin/activate

create_separator "Remove existing Ubuntu distro"

proot-distro remove ubuntu

create_separator "Install and setup proot distro"

proot-distro install ubuntu

proot-distro login ubuntu -- /bin/bash << EOF
apt update && apt upgrade -y
apt install -y zsh curl sudo

# Create a new user
useradd -m -s /bin/zsh user
echo "user:password" | chpasswd
usermod -aG sudo user

# Switch to the new user
su - user << EOL

# Install Oh My Zsh
sh -c "\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
git clone https://github.com/zsh-users/zsh-autosuggestions \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions)/' ~/.zshrc

# Install Nix
curl -L https://nixos.org/nix/install | sh -s -- --no-daemon

# Source Nix
. ~/.nix-profile/etc/profile.d/nix.sh

# Add Nix to shell configuration
echo '. ~/.nix-profile/etc/profile.d/nix.sh' >> ~/.zshrc
echo '. ~/.nix-profile/etc/profile.d/nix.sh' >> ~/.bashrc

# Install some basic Nix packages to verify installation
nix-env -iA nixpkgs.hello nixpkgs.cowsay

# Verify Nix installation
echo "Verifying Nix installation:"
nix-env --version
hello
cowsay "Nix is installed and working!"

echo "Nix has been installed and configured successfully for user 'user'."
EOL

# Set up auto-login for the new user
echo "#!/bin/bash
if [ \$(id -u) -eq 0 ]; then
    exec su - user
else
    exec zsh
fi" > /usr/local/bin/login-as-user
chmod +x /usr/local/bin/login-as-user

# Modify proot-distro login command
sed -i 's|command="bash"|command="/usr/local/bin/login-as-user"|' /data/data/com.termux/files/usr/etc/proot-distro/ubuntu.sh

echo "Setup complete. You can now login to Ubuntu and use Nix as the 'user' account."
EOF

create_separator "Finish"

end_time=$(date +%s)

elapsed_time=$((end_time - start_time))

echo "Elapsed time: $elapsed_time seconds"