# Termux

## SSH

1. Install dependencies:

```sh
pkg install openssh
```

2. Setup password with `passwd`
3. Find your username with `whoami`
4. Find the host by running `ipconfig`
5. Use `sshd` to start tha ssh server
6. connect with`ssh <username>@<host> -p8022`

## Setup

**setup**:

```sh
rm setup-termux.sh && \
wget -O setup-termux.sh https://raw.githubusercontent.com/dmenezesgabriel/setup-workstation/refs/heads/master/termux/setup-termux.sh && \
chmod +x setup-termux.sh && \
sh setup-termux.sh
```

**Nix default**:

```sh
wget https://raw.githubusercontent.com/dmenezesgabriel/setup-workstation/refs/heads/master/termux/nix/default.nix
```
