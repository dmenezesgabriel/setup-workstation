{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "termux-dev-env";

  buildInputs = [
    pkgs.git          # Git for version control
    pkgs.vim          # Vim text editor
    pkgs.htop         # Htop for system monitoring
    pkgs.nix          # Nix package manager
    pkgs.zsh          # Zsh shell
    pkgs.code-server  # Code-server for remote VS Code
  ];

  shellHook = ''
    # Install Oh My Zsh non-interactively
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

    # Install Zsh Autosuggestions plugin
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

    # Update .zshrc to use the autosuggestions plugin
    sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions)/' ~/.zshrc

    # Set Zsh as the default shell
    echo "exec zsh" > ~/.bashrc
  '';
}
