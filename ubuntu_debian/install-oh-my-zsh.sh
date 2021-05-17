#!/bin/sh
# --------------------------------------------------------------------------- #
# Docker installation script for Chromebooks
# --------------------------------------------------------------------------- #
set -e
# --------------------------------------------------------------------------- #
# Delete previous installation if exists
# --------------------------------------------------------------------------- #
echo "Deleting zsh previous installation"
OHMY_ZSH_DIR="~/.oh-my-zsh/"
if test -d "$OHMY_ZSH_DIR"; then
    echo "$OHMY_ZSH_DIR - environment exists. Deleting it"
    sudo rm -r $OHMY_ZSH_DIR
fi
# --------------------------------------------------------------------------- #
# ZSH installation
# --------------------------------------------------------------------------- #
echo "Installing Oh My Zsh"
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
# --------------------------------------------------------------------------- #
# Change default shell to zsh
# --------------------------------------------------------------------------- #
echo "Change Default shell to zsh"
# Change default shell
chsh -s $(which zsh)
# --------------------------------------------------------------------------- #
# Install plugins
# --------------------------------------------------------------------------- #
echo "Download zsh plugins"
# Download zsh plugins
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions && \
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
# --------------------------------------------------------------------------- #
# Setup plugins at config file
# --------------------------------------------------------------------------- #
echo "Setup plugins at config file"
# Create a backup and add plugins to zsh configuration file
sed -i 's/plugins=(git)/plugins=(\n  zsh-autosuggestions\n  zsh-syntax-highlighting\n)/' ~/.zshrc
# --------------------------------------------------------------------------- #
