#!/bin/sh
# --------------------------------------------------------------------------- #
# Install docker compose
# --------------------------------------------------------------------------- #
echo "Install Docker Compose's dependencies"
# Dependencies
sudo apt-get -qq update && sudo apt-get -qq install -y libffi-dev

echo "Install Docker Compose with pip"
# Install Docker Compose
# TODO upgrade pip
~/environments/general/bin/pip install docker-compose
# --------------------------------------------------------------------------- #
