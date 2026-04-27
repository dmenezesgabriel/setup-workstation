# VIM Base configuration

```sh
vim -u .vim .vimrc
```

## Installation / Setup

This repository contains a basic Vim configuration (.vimrc). To use it on your machine you can create a symlink from the repo file to your home directory. The commands below are examples — replace `/path/to/setup-workstation` with the path to this repository, or run them from the repository root.

```sh
REPO_ROOT="/path/to/setup-workstation"
# backup existing .vimrc if present and create symlink
if [ -e "$HOME/.vimrc" ] && [ ! -L "$HOME/.vimrc" ]; then
  mv "$HOME/.vimrc" "$HOME/.vimrc.backup.$(date +%Y%m%d%H%M%S)"
fi
ln -s "$REPO_ROOT/config/vim/.vimrc" "$HOME/.vimrc"

# create undo directory (used by related configs)
mkdir -p "$HOME/.vim/undodir"
```

If you're inside the repository root you can simply run:

```sh
ln -s "$(pwd)/config/vim/.vimrc" "$HOME/.vimrc"
mkdir -p "$HOME/.vim/undodir"
```

Testing

- Start Vim: `vim` and verify the configuration is loaded.
- To test a specific config file without symlinking, run:

```sh
vim -u config/vim/.vimrc
```

## File Explorer

- `:Explore`: file explorer
- `:Vexplore`: vertical file explorer
