#!/bin/bash

start_time=$(date +%s)

ZSH_PATH=~/.oh-my-zsh
ZSH_CUSTOM=$ZSH_PATH/custom
ZSH_RC_FILE=~/.zshrc

# Update package repositories
pkg update -y && pkg upgrade -y

pkg install -y git \
               libcurl
               zsh \
               curl

# Clone Oh My Zsh repository
rm -rf $ZSH_PATH
git clone https://github.com/ohmyzsh/ohmyzsh.git $ZSH_PATH

# Create a backup of the default Zsh configuration file
mv $ZSH_RC_FILE $ZSH_RC_FILE.bak

# Create a custom Zsh configuration file
cat <<EOF > $ZSH_RC_FILE
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
