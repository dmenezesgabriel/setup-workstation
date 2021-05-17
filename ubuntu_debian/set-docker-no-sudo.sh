#!/bin/zsh
# --------------------------------------------------------------------------- #
# Run docker without sudo
# --------------------------------------------------------------------------- #
echo "Removing the needs of sudo when using Docker"
sudo groupadd docker
sudo gpasswd -a $USER docker
newgrp docker
sudo usermod -aG docker $USER

echo "Restarting Docker"
# Restart docker
sudo systemctl restart docker
# --------------------------------------------------------------------------- #
