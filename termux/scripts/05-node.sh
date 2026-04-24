#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_SH="${RUN_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/lib.sh"
source "${LIB_SH}"

main() {
    echo -e "${PURPLE}Installing Node.js + pnpm...${NC}"
    echo ""

    if pkg_available nodejs-lts; then
        pkg_install "nodejs-lts" "Node.js (LTS)"
    else
        pkg_install "nodejs" "Node.js"
    fi

    if [ "${DRY_RUN}" = "1" ]; then
        log_debug "DRY_RUN: would install pnpm (npm)"
    else
        if command -v npm >/dev/null 2>&1; then
            (npm install -g pnpm >> >(while IFS= read -r line; do log_file "$line"; done) 2>&1) &
            if ! spinner $! "pnpm (npm) installer"; then
                rc=$?
                fail_step "pnpm installer failed (exit ${rc})"
            fi
        else
            warn "npm not found; skipping pnpm installer. Consider installing nodejs first."
            FAILED_STEPS+=("pnpm: npm not found")
        fi
    fi

    export PNPM_HOME="${HOME}/.local/share/pnpm"
    export PATH="${PNPM_HOME}:${PATH}"
    _append_to_rcfiles \
        'export PNPM_HOME="$HOME/.local/share/pnpm"; export PATH="$PNPM_HOME:$PATH"' \
        'LINUX_TERMINAL_PNPM_PATH'
}

main "$@"
