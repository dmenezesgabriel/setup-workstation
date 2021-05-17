#!/bin/zsh
# --------------------------------------------------------------------------- #
# Docker installation script for ubuntu
# --------------------------------------------------------------------------- #
set -e
# --------------------------------------------------------------------------- #
# Get system architecture
# --------------------------------------------------------------------------- #
ARCH=""
case $(uname -m) in
    i386)   ARCH="386" ;;
    i686)   ARCH="386" ;;
    x86_64) ARCH="amd64" ;;
    aarch64)    dpkg --print-architecture | grep -q "arm64" && ARCH="arm64" || ARCH="arm" ;;
esac

echo "System architecture: $ARCH"
# --------------------------------------------------------------------------- #
# Instructions
# --------------------------------------------------------------------------- #
cat << EOF

This is a script to install Docker on Debian linux systems.
The installation also can be done on some chromebooks using linux

This will:
2. Install docker
3. Test the instalation using the Hello world container
1. Install docker system dependencies

EOF
# --------------------------------------------------------------------------- #
read -p "Press Enter to continue ... or ctrl-c to cancel." START
echo

echo "Installing Docker"
# --------------------------------------------------------------------------- #
# Install dependencies
# --------------------------------------------------------------------------- #
sudo apt-get -qq install apt-transport-https ca-certificates curl gnupg lsb-release
# --------------------------------------------------------------------------- #
# Add Docker official GPG key
# --------------------------------------------------------------------------- #
echo "Add Docker's official GPG key"
# Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
# --------------------------------------------------------------------------- #
# Setup repository according to architecture
# --------------------------------------------------------------------------- #
echo "Setup docker repository"

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
# --------------------------------------------------------------------------- #
# Install Docker engine
# --------------------------------------------------------------------------- #
echo "Install Docker's Engine"
# Install docker engine
sudo apt-get -qq update && sudo apt-get -qq install docker-ce docker-ce-cli containerd.io
# --------------------------------------------------------------------------- #
# Test
# --------------------------------------------------------------------------- #
docker --version
