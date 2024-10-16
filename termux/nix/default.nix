{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "termux-dev-env";

  buildInputs = [
    pkgs.git
    pkgs.vim
    pkgs.nvim
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
    pkgs.python3Packages.setuptools
    pkgs.python3Packages.wheel
    pkgs.python3Packages.numpy
    pkgs.python3Packages.pandas
    pkgs.openssl
    pkgs.libffi
    pkgs.hdf5
    pkgs.openblas
  ];

  shellHook = ''
    zsh
  '';
}