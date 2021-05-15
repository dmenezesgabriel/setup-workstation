#!/bin/sh

# Any subsequent(*) commands which fail will cause the shell script to exit immediately
set -e

echo "Current user: $USER"

# Get operational system architecture

ARCH=""
case $(uname -m) in
    i386)   ARCH="386" ;;
    i686)   ARCH="386" ;;
    x86_64) ARCH="amd64" ;;
    aarch64)    dpkg --print-architecture | grep -q "arm64" && ARCH="arm64" || ARCH="arm" ;;
esac

echo "System architecture: $ARCH"

# -------------------------------------------------------------------------------------------------------------------------------------------------- #
# Essentials & dependencies
# -------------------------------------------------------------------------------------------------------------------------------------------------- #

echo "Installing dependencies"
sudo apt-get -qq update && sudo apt-get -qq install --no-install-recommends -y gcc git zsh curl vim tmux htop python3-venv python3-pip libffi-dev python3-dev make default-jre

# -------------------------------------------------------------------------------------------------------------------------------------------------- #
# Custom
# -------------------------------------------------------------------------------------------------------------------------------------------------- #

echo "Change default text editor"
sudo update-alternatives --config editor

# -------------------------------------------------------------------------------------------------------------------------------------------------- #

# Install Oh My Zsh framework
echo "Deleting zsh previous installation"
OHMY_ZSH_DIR="~/.oh-my-zsh/"
if test -d "$OHMY_ZSH_DIR"; then
    echo "$OHMY_ZSH_DIR - environment exists. Deleting it"
    sudo rm -r $OHMY_ZSH_DIR
fi

echo "Installing Oh My Zsh"
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

echo "Change Default shell to zsh"
# Change default shell
chsh -s $(which zsh)

echo "Download zsh plugins"
# Download zsh plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions && \
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting

echo "Replace zsh plugins"
# Create a backup and add plugins to zsh configuration file
sed -i 's/plugins=(git)/plugins=(\n  zsh-autosuggestions\n  zsh-syntax-highlighting\n)/' ~/.zshrc

# -------------------------------------------------------------------------------------------------------------------------------------------------- #

echo "Creating 'general' virtual environment"

# Install python virtual environment
python3 -m venv ~/environments/general


echo "Installing default python libs"
sudo apt-get -qq install -y python3-pip

~/environments/general/bin/pip install black isort pylama flake8 pytest wheel

echo "Adding custom configs to ~/.zshrc"
# TODO: fix - not writting to file
# Custom configuration at zshrc
echo "## Custom ##" >> ~/.zshrc
echo "# Activate Python general virtual environment" >> ~/.zshrc
echo 'alias generalenv="source ~/environments/general/bin/python3"' >> ~/.zshrc
echo "# Always require python environment" >> ~/.zshrc
echo "export PIP_REQUIRE_VIRTUALENV=true" >> ~/.zshrc
echo "# Don't write __pycache__, *.pyc and similar files" >> ~/.zshrc
echo "export PYTHONDONTWRITEBYTECODE=1" >> ~/.zshrc
echo "# Activate venv automagically" >> ~/.zshrc
echo "generalenv" >> ~/.zshrc

echo "Lines appended to ~/.zshrc"
tail -10 ~/.zshrc

# -------------------------------------------------------------------------------------------------------------------------------------------------- #
# Docker
# -------------------------------------------------------------------------------------------------------------------------------------------------- #

echo "Installing Docker"

echo "Setup docker repository"
# Setup the repository
sudo apt-get -qq install apt-transport-https ca-certificates curl gnupg lsb-release

echo "Add Docker's official GPG key"
# Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

if [ "$ARCH" = "amd64" ]; then
    echo \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
elif [ "$ARCH" = "armhf" ]; then
    echo \
    "deb [arch=armhf signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
elif [ "$ARCH" = "arm64" ]; then
    echo \
    "deb [arch=arm64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
fi

echo "Install Docker's Engine"
# Install docker engine
sudo apt-get -qq update && sudo apt-get -qq install docker-ce docker-ce-cli containerd.io

docker --version

# -------------------------------------------------------------------------------------------------------------------------------------------------- #

echo "Install Docker Compose's dependencies"
# Dependencies
sudo apt-get -qq update && sudo apt-get -qq install -y libffi-dev

echo "Install Docker Compose with pip"
# Install Docker Compose
~/environments/general/bin/pip install docker-compose

echo "Removing the needs of sudo when using Docker"
sudo groupadd docker
sudo gpasswd -a $USER docker
newgrp docker
sudo usermod -aG docker $USER

echo "Restarting Docker"
# Restart docker
sudo systemctl restart docker

# -------------------------------------------------------------------------------------------------------------------------------------------------- #
# SSH Key
# -------------------------------------------------------------------------------------------------------------------------------------------------- #

echo "Creating a new SSH key within the default name id_ed25519"
r
ead -p "Your email: " email
ssh-keygen -t ed25519 -C "$email"

#Start the ssh-agent in the background
eval "$(ssh-agent -s)"
# Add your SSH private key to the ssh-agent
ssh-add ~/.ssh/id_ed25519

# -------------------------------------------------------------------------------------------------------------------------------------------------- #
# Finish
# -------------------------------------------------------------------------------------------------------------------------------------------------- #

read -p "Reboot system(y/n): " reboot_system
if [ $reboot_system = "y"]; then
    sudo reboot -h now
else
    echo "Skipping"
fi

echo "Setup finished, Happy Hacking! ;-)"
