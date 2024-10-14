#!/bin/bash

# Define color codes
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to create centered separator
create_separator() {
    local text="$1"
    local total_length=40
    local text_length=${#text}
    local padding=$(( (total_length - text_length) / 2 ))
    local separator=$(printf '%*s' "$padding" | tr ' ' '=')
    echo -e "${GREEN}${separator} ${text} ${separator}${NC}\n"
}

start_time=$(date +%s)

create_separator "Install dependencies"

pkg update && pkg upgrade -y
pkg install -y \
    x11-repo \
    proot \
    proot-distro \
    tur-repo \
    pulseaudio \
    openssh \
    git \
    curl \
    wget \
    zsh \
    tmux \
    vim \
    build-essential \
    python \
    python-pip \
    nodejs-lts

create_separator "Create virtual environment"

rm -rf ~/environments/general && \
python -m venv --system-site-packages ~/environments/general && \
echo "source ~/environments/general/bin/activate" >> ~/.bashrc && \
source ~/environments/general/bin/activate

create_separator "Remove existing Ubuntu distro"

proot-distro remove ubuntu

create_separator "Install and setup proot distro"

proot-distro install ubuntu

# Login to Ubuntu and set up user, Zsh, and Oh My Zsh
proot-distro login ubuntu -- /bin/bash << EOF
apt update && apt upgrade -y
apt install -y zsh

sh -c "\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
git clone https://github.com/zsh-users/zsh-autosuggestions \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions)/' ~/.zshrc
echo "exec zsh" > ~/.bashrc

EOF

create_separator "Finish"

end_time=$(date +%s)

elapsed_time=$((end_time - start_time))

echo "Elapsed time: $elapsed_time seconds"