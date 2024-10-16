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
}
