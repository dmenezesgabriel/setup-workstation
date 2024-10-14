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

read -r -p "Select a username: " username </dev/tty
read -r -s -p "Enter password for $username: " password </dev/tty
echo # move to a new line

create_separator "Install dependencies"

termux-change-repo

pkg update && pkg upgrade -y

yes | pkg install x11-repo
yes | pkg update

pkg install -y \
    dbus \
    proot \
    proot-distro \
    pulseaudio \
    virglrenderer-android \
    pavucontrol-qt \
    firefox \
    tur-repo \
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

termux-setup-storage

create_separator "Create virtual environment"

rm -rf ~/environments/general && \
python -m venv --system-site-packages ~/environments/general && \
echo "source ~/environments/general/bin/activate" >> ~/.bashrc && \
source ~/environments/general/bin/activate

create_separator "Install and setup proot distro"

yes | proot-distro remove ubuntu
yes | proot-distro install ubuntu
yes | proot-distro login ubuntu --shared-tmp -- apt update
yes | proot-distro login ubuntu --shared-tmp -- apt upgrade

proot-distro login ubuntu --shared-tmp -- groupadd storage
proot-distro login ubuntu --shared-tmp -- groupadd wheel
proot-distro login ubuntu --shared-tmp -- useradd -m -g users -G wheel,audio,video,storage -s /bin/bash "$username"

echo "$username:$password" | proot-distro login ubuntu --shared-tmp -- chpasswd

chmod u+rw $HOME/../usr/var/lib/proot-distro/installed-rootfs/ubuntu/etc/sudoers
echo "$username ALL=(ALL) ALL" | tee -a $HOME/../usr/var/lib/proot-distro/installed-rootfs/ubuntu/etc/sudoers > /dev/null
chmod u-w $HOME/../usr/var/lib/proot-distro/installed-rootfs/ubuntu/etc/sudoers

proot-distro login ubuntu -- /bin/bash << EOF
apt update && apt upgrade -y
apt install -y zsh curl sudo

usermod -aG sudo $username

sh -c "\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
git clone https://github.com/zsh-users/zsh-autosuggestions \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions)/' ~/.zshrc
echo "exec zsh" > ~/.bashrc

curl -L https://nixos.org/nix/install | sh -s -- --no-daemon

. ~/.nix-profile/etc/profile.d/nix.sh

echo '. ~/.nix-profile/etc/profile.d/nix.sh' >> ~/.zshrc
echo '. ~/.nix-profile/etc/profile.d/nix.sh' >> ~/.bashrc

nix-env -iA nixpkgs.hello nixpkgs.cowsay

echo "Verifying Nix installation:"
nix-env --version
hello
cowsay "Nix is installed and working!"

EOF

create_separator "Finish"

end_time=$(date +%s)

elapsed_time=$((end_time - start_time))

echo "Elapsed time: $elapsed_time seconds"