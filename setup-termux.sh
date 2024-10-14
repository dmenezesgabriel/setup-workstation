#!/bin/bash

# Define color codes
GREEN='\033[0;32m'
NC='\033[0m' # No Color

start_time=$(date +%s)

echo -e "${GREEN}================= Install dependencies =================${NC}\n"

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

echo -e "${GREEN}=============== Create virtual environment ==============${NC}\n"

rm -rf ~/environments/general && \
python -m venv --system-site-packages ~/environments/general && \
echo "source ~/environments/general/bin/activate" >> ~/.bashrc && \
source ~/environments/general/bin/activate

echo -e "${GREEN}=========== Remove existing Ubuntu distro ==============${NC}\n"

proot-distro remove ubuntu

echo -e "${GREEN}=========== Install and setup proot distro ==============${NC}\n"

proot-distro install ubuntu

# Login to Ubuntu and set up user, Zsh, and Oh My Zsh
proot-distro login ubuntu -- /bin/bash << EOF
apt update && apt upgrade -y
apt install -y zsh

sh -c "\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
git clone https://github.com/zsh-users/zsh-autosuggestions \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions)/' ~/.zshrc

EOF

echo -e "${GREEN}======================= Finish ========================${NC}\n"

end_time=$(date +%s)

elapsed_time=$((end_time - start_time))

echo "Elapsed time: $elapsed_time seconds"
