{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "termux-dev-env";

  buildInputs = [
    pkgs.git
    pkgs.vim
    pkgs.htop
    pkgs.nix
    pkgs.zsh
    pkgs.ncdu
    pkgs.code-server
  ];

  shellHook = ''
    zsh
  '';
}
