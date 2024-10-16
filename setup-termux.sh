#!/bin/bash

TERMUXX_DIR="$HOME/.termux"
TERMUXX_PROPERTIES="$TERMUXX_DIR/termux.properties"
EXTRA_KEYS="extra-keys = [ \
    ['ESC', 'TAB', 'CTRL', 'ALT', '(', ')', '{', '}', '[', ']'], \
    [';', ':', '\'', '\"', '<', '>', '/', '|', '=', '+', '_'], \
    ['UP', 'DOWN', 'LEFT', 'RIGHT', 'DEL', 'BACKSPACE', '-', '*', '&', '%'] \
]"
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

    echo "$EXTRA_KEYS" > "$TERMUXX_PROPERTIES"

    termux-reload-settings
}

install_dependencies() {
    create_separator "Install dependencies"

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
    apt install -y zsh curl sudo

    echo "$username ALL=(ALL) ALL" | tee -a /etc/sudoers > /dev/null
    su - $username

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

    add_extra_keyboard_keys

    install_dependencies

    termux-setup-storage

    create_python_venv

    setup_proot_distro

    create_separator "Finish"

    end_time=$(date +%s)

    elapsed_time=$((end_time - start_time))

    echo "Elapsed time: $elapsed_time seconds"
}