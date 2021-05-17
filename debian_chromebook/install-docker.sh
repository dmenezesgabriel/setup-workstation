#!/bin/zsh
# --------------------------------------------------------------------------- #
# Docker installation script for Chromebooks
# --------------------------------------------------------------------------- #
set -e
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
# --------------------------------------------------------------------------- #
# Remove already installed previous versions
# --------------------------------------------------------------------------- #
echo
echo "Removing already installed previous versions"
echo "You may be asked to input your administrator 'sudo password' ... "
# --------------------------------------------------------------------------- #
# # Remove old versions
# --------------------------------------------------------------------------- #
# sudo apt-get remove docker docker-engine docker.io containerd runc
# --------------------------------------------------------------------------- #
echo "Installing prerequisites"

# Update the apt package index and install packages to allow apt to use a repository over HTTPS
 sudo apt-get update -y
 sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common

echo
echo "Download and install Docker"
# --------------------------------------------------------------------------- #
# Set up the stable repository
# --------------------------------------------------------------------------- #
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian \
   $(lsb_release -cs) \
   stable"
# --------------------------------------------------------------------------- #
# Add Docker’s official GPG key
# --------------------------------------------------------------------------- #
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
# --------------------------------------------------------------------------- #
# Install Docker
# --------------------------------------------------------------------------- #
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io
# --------------------------------------------------------------------------- #
echo
echo "Finished."
echo
# --------------------------------------------------------------------------- #
read -p "Press Enter to run the 'Hello World' Docker container as a test: " START
echo
# --------------------------------------------------------------------------- #
# Test installation
# --------------------------------------------------------------------------- #
sudo docker run hello-world
# --------------------------------------------------------------------------- #
