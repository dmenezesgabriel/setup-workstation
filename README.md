# Setup Workstation

# Setup Workstation

## Vim

```sh
# .vimrc → ~/.vimrc
[ -f ~/.vimrc ] && mv ~/.vimrc ~/.vimrc.bak
wget -O ~/.vimrc https://raw.githubusercontent.com/dmenezesgabriel/setup-workstation/master/vim/.vimrc
```

or

```sh
[ -f ~/.vimrc ] && mv ~/.vimrc ~/.vimrc.bak
curl -o ~/.vimrc https://raw.githubusercontent.com/dmenezesgabriel/setup-workstation/master/vim/.vimrc
```

## Neovim

```sh
# init.lua → ~/.config/nvim/init.lua
mkdir -p ~/.config/nvim
[ -f ~/.config/nvim/init.lua ] && mv ~/.config/nvim/init.lua ~/.config/nvim/init.lua.bak
wget -O ~/.config/nvim/init.lua https://raw.githubusercontent.com/dmenezesgabriel/setup-workstation/master/nvim/init.lua
```

or

```sh
[ -f ~/.config/nvim/init.lua ] && mv ~/.config/nvim/init.lua ~/.config/nvim/init.lua.bak
curl -o ~/.config/nvim/init.lua https://raw.githubusercontent.com/dmenezesgabriel/setup-workstation/master/nvim/init.lua
```

## Bash

```sh
# .bashrc → ~/.bashrc
[ -f ~/.bashrc ] && mv ~/.bashrc ~/.bashrc.bak
wget -O ~/.bashrc https://raw.githubusercontent.com/dmenezesgabriel/setup-workstation/master/bash/.bashrc
```

or

```sh
[ -f ~/.bashrc ] && mv ~/.bashrc ~/.bashrc.bak
curl -o ~/.bashrc https://raw.githubusercontent.com/dmenezesgabriel/setup-workstation/master/bash/.bashrc
```

## Tmux

```sh
# .tmux.conf → ~/.tmux.conf
[ -f ~/.tmux.conf ] && mv ~/.tmux.conf ~/.tmux.conf.bak
wget -O ~/.tmux.conf https://raw.githubusercontent.com/dmenezesgabriel/setup-workstation/master/tmux/.tmux.conf
```

or

```sh
[ -f ~/.tmux.conf ] && mv ~/.tmux.conf ~/.tmux.conf.bak
curl -o ~/.tmux.conf https://raw.githubusercontent.com/dmenezesgabriel/setup-workstation/master/tmux/.tmux.conf
```

## Useful commands

```sh
tree -L 2 -I "node_modules" -a
```

## Resources

- [ubuntu-x11-app.sh](https://github.com/01101010110/proot-distro-scripts/blob/main/ubuntu-x11-app.sh)
