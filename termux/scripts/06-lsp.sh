#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_SH="${RUN_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/lib.sh"
# shellcheck disable=SC1091
# shellcheck source=../lib.sh
source "${LIB_SH}"

main() {
    local node_install_failed=1
    local -a node_pkgs=(pyright typescript typescript-language-server)
    local max_attempts=3
    local backoff=5
    local rc

    echo -e "${PURPLE}Installing language servers...${NC}"
    echo ""

    export GOPATH="${GOPATH:-$HOME/go}"
    export PATH="${GOPATH}/bin:${PNPM_HOME:-$HOME/.local/share/pnpm}:$PATH"

    if [ "${DRY_RUN}" = "1" ]; then
        log_debug "DRY_RUN: would install language servers: ${node_pkgs[*]} and gopls"
        return 0
    fi

    # Prefer npm first, fallback to pnpm if npm is not available or fails
    if command -v npm >/dev/null 2>&1; then
        if run_with_retries_arr "npm: installing Node LSPs" "${max_attempts}" "${backoff}" -- npm install -g "${node_pkgs[@]}"; then
            node_install_failed=0
        fi
    fi

    if [ ${node_install_failed} -eq 1 ] && command -v pnpm >/dev/null 2>&1; then
        if run_with_retries_arr "pnpm: installing Node LSPs" "${max_attempts}" "${backoff}" -- pnpm add -g --prefer-offline "${node_pkgs[@]}"; then
            node_install_failed=0
        fi
    fi

    if [ ${node_install_failed} -eq 1 ]; then
        fail_step "Node LSP install failed after ${max_attempts} attempts (npm/pnpm)"
    fi

    # Install gopls
    if command -v go >/dev/null 2>&1; then
        if ! run_with_spinner_arr "go: installing gopls" -- env GO111MODULE=on go install golang.org/x/tools/gopls@latest; then
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
