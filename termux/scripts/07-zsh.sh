#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_SH="${RUN_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/lib.sh"
source "${LIB_SH}"

main() {
    echo -e "${PURPLE}Installing Oh My Zsh + plugins...${NC}"
    echo ""

    local omz_dir="${HOME}/.oh-my-zsh"
    local zshrc="${HOME}/.zshrc"

    rm -rf "${omz_dir}" 2>/dev/null || true

    (
        RUNZSH=no CHSH=no \
        curl -fsSL \
            https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh \
            | sh >> >(while IFS= read -r line; do log_file "$line"; done) 2>&1
    ) &
    if ! spinner $! "Oh My Zsh installer"; then
        rc=$?
        fail_step "Oh My Zsh installer failed (exit ${rc})"
    fi

    local custom_dir="${omz_dir}/custom/plugins"
    mkdir -p "${custom_dir}"

    (git clone --depth=1 \
        https://github.com/zsh-users/zsh-autosuggestions \
        "${custom_dir}/zsh-autosuggestions" >> >(while IFS= read -r line; do log_file "$line"; done) 2>&1) &
    if ! spinner $! "plugin: zsh-autosuggestions"; then
        rc=$?
        fail_step "zsh-autosuggestions clone failed (exit ${rc})"
    fi

    (git clone --depth=1 \
        https://github.com/zsh-users/zsh-syntax-highlighting \
        "${custom_dir}/zsh-syntax-highlighting" >> >(while IFS= read -r line; do log_file "$line"; done) 2>&1) &
    if ! spinner $! "plugin: zsh-syntax-highlighting"; then
        rc=$?
        fail_step "zsh-syntax-highlighting clone failed (exit ${rc})"
    fi

    if [ -f "${zshrc}" ]; then
        sed -i 's|^ZSH_THEME=.*|ZSH_THEME="robbyrussell"|' "${zshrc}"
        sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "${zshrc}"
        info ".zshrc patched (theme: robbyrussell, plugins enabled)"
    else
        warn "~/.zshrc not found — creating minimal config."
        cat > "${zshrc}" << 'MINZSH'
export ZSH="${HOME}/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source "${ZSH}/oh-my-zsh.sh"
MINZSH
    fi

    if ! grep -q 'LINUX_DESKTOP_ZSH_PATHS' "${zshrc}" 2>/dev/null; then
        cat >> "${zshrc}" << 'ZSHPATHS'

# ── Terminal: PATH ──────────────────────────────── LINUX_DESKTOP_ZSH_PATHS
export PATH="$HOME/.local/bin:$PATH"
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
ZSHPATHS
    fi

    if ! grep -q 'ZSH_AUTOSUGGEST_USE_ASYNC' "${zshrc}" 2>/dev/null; then
        cat >> "${zshrc}" << 'ZSHAUTO'

# ── Terminal: zsh-autosuggestions ──────────────────────────────────────
ZSH_AUTOSUGGEST_USE_ASYNC=1
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
bindkey '\e[C' autosuggest-accept   # right-arrow accepts suggestion
ZSHAUTO
    fi

    if ! grep -q 'LINUX_DESKTOP_ZSH_HIST' "${zshrc}" 2>/dev/null; then
        cat >> "${zshrc}" << 'ZSHHIST'

# ── Terminal: history ──────────────────────────── LINUX_DESKTOP_ZSH_HIST
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=10000
export SAVEHIST=10000
setopt SHARE_HISTORY
ZSHHIST
    fi

    if chsh -s zsh >> >(while IFS= read -r line; do log_file "$line"; done) 2>&1; then
        info "Default shell set to zsh"
    else
        warn "chsh -s zsh failed — run it manually: chsh -s zsh"
    fi
}

main "$@"
