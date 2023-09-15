#!/bin/bash

start_time=$(date +%s)

echo "\n========== Install packages ==========\n"

apt install -y neovim \
               python \
               nodejs \
               git \
               wget

echo "\n========== Use nvchad config ==========\n"

git clone https://github.com/NvChad/NvChad ~/.config/nvim --depth 1 && nvim

end_time=$(date +%s)

elapsed_time=$((end_time - start_time))

echo "Elapsed time: $elapsed_time seconds"