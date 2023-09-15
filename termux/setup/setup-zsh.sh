#!/bin/bash

start_time=$(date +%s)

ZSH_CUSTOM=~/.oh-my-zsh/custom

# Update package repositories
pkg update -y && pkg upgrade -y

pkg install -y git \
               libcurl
               zsh \
               curl

# Clone Oh My Zsh repository
rm -rf ~/.oh-my-zsh
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

end_time=$(date +%s)

elapsed_time=$((end_time - start_time))

echo "Elapsed time: $elapsed_time seconds"