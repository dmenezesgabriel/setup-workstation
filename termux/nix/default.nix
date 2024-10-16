{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "termux-dev-env";

  buildInputs = [
    pkgs.git
    pkgs.vim
    pkgs.zsh
    pkgs.nix
    pkgs.htop
    pkgs.ncdu
    pkgs.tmux
    pkgs.code-server

    # Build tools
    pkgs.gcc
    pkgs.gnumake

    # Node.js LTS
    pkgs.nodejs_22

    # Python and pandas dependencies
    pkgs.python3
    pkgs.python3Packages.pip
  ];
}