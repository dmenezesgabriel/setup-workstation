echo "Install deps"
pkg install neovim python nodejs git wget
echo "Use nvchad config"
git clone https://github.com/NvChad/NvChad ~/.config/nvim --depth 1 && nvim
