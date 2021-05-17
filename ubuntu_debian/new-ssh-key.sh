#!/bin/sh
# --------------------------------------------------------------------------- #
# SSH Key
# --------------------------------------------------------------------------- #
echo "Creating a new SSH key"
read -p "Your key name: " key_name
read -p "Your email: " email
ssh-keygen -t $key_name -C "$email"
# --------------------------------------------------------------------------- #
#Start the ssh-agent in the background
eval "$(ssh-agent -s)"
# Add your SSH private key to the ssh-agent
ssh-add ~/.ssh/$key_name
# --------------------------------------------------------------------------- #
