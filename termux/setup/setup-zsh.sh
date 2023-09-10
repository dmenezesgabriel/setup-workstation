#!/bin/bash

ZSH_CUSTOM=~/.oh-my-zsh/custom

termux-change-repo

# Update package repositories
pkg update -y && pkg upgrade -y

pkg remove -y git
pkg remove -y libcurl
pkg install -y git
pkg install -y libcurl

# Install Zsh and other required packages
pkg install -y zsh \
               curl

# Clone Oh My Zsh repository
rm -r ~/.oh-my-zsh
git clone https://github.com/ohmyzsh/ohmyzsh.git

# Create a backup of the default Zsh configuration file
mv ~/.zshrc ~/.zshrc.bak

# Create a custom Zsh configuration file
cat <<EOF > ~/.zshrc
export ZSH="/data/data/com.termux/files/home/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

alias ll='ls -l'

EOF

# Install additional plugins if needed
# Example: Install the "zsh-syntax-highlighting" plugin
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions.git $ZSH_CUSTOM/plugins/zsh-autosuggestions

# Start Zsh
zsh