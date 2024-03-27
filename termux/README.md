# Termux

- **Run docker termux image**:

```sh
docker-compose run --rm termux
```

- **Install NerdFonts**:

```sh
curl -o setup-nerdfonts.sh https://raw.githubusercontent.com/dmenezesgabriel/setup-workstation/master/termux/setup/setup-nerdfonts.sh && chmod 755 ./setup-nerdfonts.sh && sh ./setup-nerdfonts.sh
```

- **Install Oh my ZSH**:

```sh
curl -o setup-zsh.sh https://raw.githubusercontent.com/dmenezesgabriel/setup-workstation/master/termux/setup/setup-zsh.sh && chmod 755 ./setup-zsh.sh && sh ./setup-zsh.sh
```

- **Install Neovim**:

```sh
curl -o setup-neovim.sh https://raw.githubusercontent.com/dmenezesgabriel/setup-workstation/master/termux/setup/setup-neovim.sh && chmod 755 ./setup-neovim.sh && sh ./setup-neovim.sh
```

- **Install Python packages**:

_Streamlit & Jupyter_

```sh
curl -o setup-py-data-venv.sh https://raw.githubusercontent.com/dmenezesgabriel/setup-workstation/master/termux/setup/setup-py-data-venv.sh && chmod 755 ./setup-py-data-venv.sh && sh ./setup-py-data-venv.sh ~/Documents/repos/notebooks
```
