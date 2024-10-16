{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "termux-dev-env";

  buildInputs = [
    pkgs.git          # Git for version control
    pkgs.vim          # Vim text editor
    pkgs.htop         # Htop for monitoring system processes
    pkgs.code-server  # Code-server for remote VS Code
    pkgs.nix          # Nix package manager
  ];

  shellHook = ''
    # Set up pyenv for managing Python versions
    if ! command -v pyenv > /dev/null; then
      curl https://pyenv.run | bash
      export PATH="$HOME/.pyenv/bin:$PATH"
      eval "$(pyenv init --path)"
      eval "$(pyenv init -)"
      eval "$(pyenv virtualenv-init -)"
    fi

    # Set up nvm for managing Node.js versions
    if ! command -v nvm > /dev/null; then
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
      export NVM_DIR="$HOME/.nvm"
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    fi

    echo "Development environment is ready!"
  '';
}
