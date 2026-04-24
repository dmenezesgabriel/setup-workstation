#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_SH="${RUN_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/lib.sh"
source "${LIB_SH}"

main() {
    echo -e "${PURPLE}Installing language servers...${NC}"
    echo ""

    export GOPATH="${GOPATH:-$HOME/go}"
    export PATH="${GOPATH}/bin:${PNPM_HOME:-$HOME/.local/share/pnpm}:$PATH"

    if [ "${DRY_RUN}" = "1" ]; then
        log_debug "DRY_RUN: would install language servers: pyright, typescript-language-server, gopls"
        return 0
    fi

    node_install_failed=1
    node_pkgs="pyright typescript typescript-language-server"
    max_attempts=3
    backoff=5

    # Prefer npm first, fallback to pnpm if npm is not available or fails
    if command -v npm >/dev/null 2>&1; then
        attempt=1
        while [ ${attempt} -le ${max_attempts} ]; do
            log_debug "npm attempt ${attempt}/${max_attempts}"
            (npm install -g ${node_pkgs} >> >(while IFS= read -r line; do log_file "$line"; done) 2>&1) &
            if spinner $! "npm: installing Node LSPs (attempt ${attempt}/${max_attempts})"; then
                node_install_failed=0
                break
            else
                rc=$?
                log_debug "npm attempt ${attempt} failed (rc=${rc}), sleeping ${backoff}s"
                attempt=$((attempt+1))
                sleep ${backoff}
                backoff=$((backoff*2))
            fi
        done
    fi

    if [ ${node_install_failed} -eq 1 ] && command -v pnpm >/dev/null 2>&1; then
        attempt=1
        backoff=5
        while [ ${attempt} -le ${max_attempts} ]; do
            log_debug "pnpm attempt ${attempt}/${max_attempts} (prefer-offline)"
            (pnpm add -g --prefer-offline ${node_pkgs} >> >(while IFS= read -r line; do log_file "$line"; done) 2>&1) &
            if spinner $! "pnpm: installing Node LSPs (attempt ${attempt}/${max_attempts})"; then
                node_install_failed=0
                break
            else
                rc=$?
                log_debug "pnpm attempt ${attempt} failed (rc=${rc}), sleeping ${backoff}s"
                attempt=$((attempt+1))
                sleep ${backoff}
                backoff=$((backoff*2))
            fi
        done
    fi

    if [ ${node_install_failed} -eq 1 ]; then
        fail_step "Node LSP install failed after ${max_attempts} attempts (npm/pnpm)"
    fi

    # Install gopls
    if command -v go >/dev/null 2>&1; then
        (GO111MODULE=on go install golang.org/x/tools/gopls@latest >> >(while IFS= read -r line; do log_file "$line"; done) 2>&1) &
        if ! spinner $! "go: installing gopls"; then
            rc=$?; fail_step "go install gopls failed (exit ${rc})"
        fi
    else
        warn "go not found; skipping gopls"
        FAILED_STEPS+=("gopls: go missing")
    fi

    # Install lsp-wrapper from configs
    mkdir -p "${HOME}/.local/bin" 2>/dev/null || true
    install_config "${CONFIG_DIR}/bin/lsp-wrapper" "${HOME}/.local/bin/lsp-wrapper"
    chmod +x "${HOME}/.local/bin/lsp-wrapper" 2>/dev/null || true

    info "Language server installation attempted"
}

main "$@"
