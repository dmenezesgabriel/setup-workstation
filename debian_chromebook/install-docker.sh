#!/bin/bash
set -e

cat << EOF

This is a script to install Docker on Debian linux systems.
The installation also can be done on some chromebooks using linux

This will:
2. Install docker
3. Test the instalation using the Hello world container
1. Install docker system dependencies

EOF

read -p "Ṕress Enter to continue ... or ctrl-c to cancel." START
echo

echo
echo "Removing already installed previous versions"
echo "You may be asked to input your administrator 'sudo password' ... "

# # Remove old versions
# sudo apt-get remove docker docker-engine docker.io containerd runc

echo "Installing prerequisites"

# Update the apt package index and install packages to allow apt to use a repository over HTTPS
 sudo apt-get update
 sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

echo
echo "Download and install Docker"

# Add Docker’s official GPG key
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up the stable repository
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null


sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io"

echo
echo "Finished."
echo

read -p "Press Enter to run the 'Hello World' Docker container as a test: " START
echo

# 
docker run hello-world