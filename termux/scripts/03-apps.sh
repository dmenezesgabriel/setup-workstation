#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_SH="${RUN_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/lib.sh"
# shellcheck disable=SC1091
# shellcheck source=../lib.sh
source "${LIB_SH}"

main() {
    echo -e "${PURPLE}Installing core shell and development toolchain...${NC}"
    echo ""

    install_pkg_list "Shell/Dev Tools" git curl wget tmux vim neovim fd ripgrep tree zsh openssh golang

    install_pkg_list "Build toolchain" build-essential llvm lld rust cmake ninja pkg-config patchelf libandroid-execinfo

    # GOPATH and PATH
    # shellcheck disable=SC2016
    _append_to_rcfiles 'export GOPATH="$HOME/go"; export PATH="$GOPATH/bin:$PATH"' 'LINUX_TERMINAL_GO_PATH'

    # Install configs from config/
    mkdir -p "${HOME}/.config/nvim" "${HOME}/.config/nvim/lua" "${HOME}/.vim" 2>/dev/null || true

    install_config "${CONFIG_DIR}/vim/vimrc" "${HOME}/.vimrc"
    install_config "${CONFIG_DIR}/nvim/init.lua" "${HOME}/.config/nvim/init.lua"

    info "Wrote ${HOME}/.vimrc and ${HOME}/.config/nvim/init.lua"
}

main "$@"
