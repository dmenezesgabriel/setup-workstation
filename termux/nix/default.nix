{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "termux-dev-env";

  buildInputs = [
    pkgs.git
    pkgs.vim
    pkgs.htop
    pkgs.nix
    pkgs.zsh
    pkgs.code-server
  ];

  shellHook = ''
    sh -c "\$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    git clone https://github.com/zsh-users/zsh-autosuggestions \${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions)/' ~/.zshrc
    echo "exec zsh" > ~/.bashrc
  '';
}
