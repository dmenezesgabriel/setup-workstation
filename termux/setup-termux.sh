#!/bin/bash

TERMUXX_DIR="$HOME/.termux"
TERMUXX_PROPERTIES="$TERMUXX_DIR/termux.properties"
NERD_FONTS_PATH=~/NerdFonts
GREEN='\033[0;32m'
NC='\033[0m' # No Color

create_separator() {
    local text="$1"
    local total_length=40
    local text_length=${#text}
    local padding=$(( (total_length - text_length) / 2 ))
    local separator=$(printf '%*s' "$padding" | tr ' ' '=')
    echo -e "${GREEN}${separator} ${text} ${separator}${NC}\n"
}

add_extra_keyboard_keys() {
    create_separator "Add extra keyboard keys"

    if [ ! -d "$TERMUXX_DIR" ]; then
        mkdir -p "$TERMUXX_DIR"
        echo "Created directory: $TERMUXX_DIR"
    fi

    if [ -f "$TERMUXX_PROPERTIES" ]; then
        sed -i '/extra-keys\s*=/,/]/d' "$TERMUXX_PROPERTIES"
        echo "Removed existing extra-keys configuration from $TERMUXX_PROPERTIES"
    fi

    cat <<EOF | tee -a "$TERMUXX_PROPERTIES" > /dev/null
    extra-keys = [ \
        ['ESC', '!', '&', '%', '(', ')', '{', '}', '[', ']'], \
        ['TAB', '\\\'', '\"', '<', '>', '/', '=', '+', '|'], \
        ['HOME', '~', '_', '-', '*', '\`', '\´', 'UP', 'END'], \
        ['CTRL', ':', ';','ALT', 'DEL', 'BACKSPACE', 'LEFT', 'DOWN', 'RIGHT'] \
    ]
EOF
}

add_nerd_fonts() {
    create_separator "Create NerdFonts directory"

    rm -rf $NERD_FONTS_PATH
    mkdir -p $NERD_FONTS_PATH

    echo "Change directory to NerdFonts"

    cd $NERD_FONTS_PATH

    echo "Download FiraCode font"

    wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/FiraCode.zip

    echo "Unzip FiraCode"

    unzip FiraCode.zip

    mv FiraCodeNerdFont-Regular.ttf ~/.termux/font.ttf
}

install_dependencies() {
    create_separator "Install dependencies"

    pkg update && pkg upgrade -y

    yes | pkg install x11-repo tur-repo build-essential binutils pkg-config
    yes | pkg update

    pkg install --fix-policy -y \
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
        libandroid-execinfo \
        libarrow-cpp \
        make \
        clang \
        ninja \
        rust \
        libffi \
        binutils \
        libzmq \
        libjpeg-turbo \
        python \
        python-pip \
        python-numpy \
        python-pandas \
        python-pyarrow \
        python-scipy \
        nodejs-lts \
        code-server
}

setup_zsh() {
    create_separator "Setup Oh My ZSH"

    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions)/' ~/.zshrc
}

create_python_venv() {
    create_separator "Create virtual environment"

    rm -rf ~/environments/general && \

    python -m venv --system-site-packages ~/environments/general && \

    echo "source ~/environments/general/bin/activate" >> ~/.bashrc && \

    . ~/environments/general/bin/activate
}

setup_proot_distro() {
    create_separator "Install and setup proot distro"

    yes | proot-distro remove ubuntu
    yes | proot-distro install ubuntu
    yes | proot-distro login ubuntu --shared-tmp -- apt update
    yes | proot-distro login ubuntu --shared-tmp -- apt upgrade

    proot-distro login ubuntu --shared-tmp -- groupadd storage
    proot-distro login ubuntu --shared-tmp -- groupadd wheel
    proot-distro login ubuntu --shared-tmp -- useradd -m -g users -G wheel,audio,video,storage -s /bin/bash "$username"

    echo "$username:$password" | proot-distro login ubuntu --shared-tmp -- chpasswd


    proot-distro login ubuntu -- /bin/bash << EOF
    apt update && apt upgrade -y
    apt install -y zsh curl wget sudo

    echo "$username ALL=(ALL) ALL" | tee -a /etc/sudoers > /dev/null
    su - $username

    sh -c "\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    git clone https://github.com/zsh-users/zsh-autosuggestions \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions)/' ~/.zshrc
    echo "exec zsh" > ~/.bashrc

    echo "$password" | sudo -S mkdir -p /nix
    echo "$password" | sudo -S chown -R $username /nix

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

    proot-distro login ubuntu -- /bin/bash << EOF
    echo "exec su - $username" > ~/.bashrc
EOF

}

main() {
    start_time=$(date +%s)

    read -r -p "Select a username: " username </dev/tty
    echo "Username: $username"

    read -r -p "Enter password for $username: " password </dev/tty
    echo "Password entered: [hidden]"

    install_dependencies

    setup_zsh

    create_python_venv

    setup_proot_distro

    add_nerd_fonts
    add_extra_keyboard_keys

    termux-reload-settings

    create_separator "Finish"

    end_time=$(date +%s)

    elapsed_time=$((end_time - start_time))

    echo "Elapsed time: $elapsed_time seconds"
}

main
