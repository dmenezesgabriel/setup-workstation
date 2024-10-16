# Setup Workstation

Useful installation scripts for linux

> :warning: **Work in progress**: Some scripts may not be finished!

## Termux

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

## Resources

- [ubuntu-x11-app.sh](https://github.com/01101010110/proot-distro-scripts/blob/main/ubuntu-x11-app.sh)
