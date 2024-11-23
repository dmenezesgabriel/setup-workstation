#!/bin/sh

# List of extensions
# code --list-extensions
cat <<EOF | xargs -L 1 code --install-extension
bierner.emojisense
bradlc.vscode-tailwindcss
dbaeumer.vscode-eslint
dendron.dendron
dendron.dendron-paste-image
esbenp.prettier-vscode
formulahendry.auto-rename-tag
hashicorp.terraform
humao.rest-client
marp-team.marp-vscode
miguelsolorio.min-theme
miguelsolorio.symbols
mikestead.dotenv
ms-azuretools.vscode-docker
ms-python.black-formatter
ms-python.debugpy
ms-python.isort
ms-python.python
ms-python.vscode-pylance
ms-toolsai.jupyter
ms-toolsai.jupyter-keymap
ms-toolsai.jupyter-renderers
ms-toolsai.vscode-jupyter-cell-tags
ms-toolsai.vscode-jupyter-slideshow
ms-vscode.js-debug-nightly
ms-vscode.vscode-typescript-next
mtxr.sqltools
mtxr.sqltools-driver-pg
prisma.prisma
shardulm94.trailing-spaces
streetsidesoftware.code-spell-checker
streetsidesoftware.code-spell-checker-portuguese-brazilian
vitest.explorer
vscodevim.vim
vue.volar
wallabyjs.console-ninja
wallabyjs.quokka-vscode
yandeu.five-server
EOF
