#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_SH="${RUN_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/lib.sh"
# shellcheck disable=SC1091
source "${LIB_SH}"

main() {
    echo -e "${PURPLE}Installing code-server (Termux) ...${NC}"
    echo ""

    if [ "${DRY_RUN}" = "1" ]; then
        log_debug "DRY_RUN: would install code-server"
        return 0
    fi

    # Try Termux package (preferred)
    if pkg_available "tur-repo"; then
        info "Ensuring Termux 'tur-repo' is present"
        pkg_install "tur-repo" "tur-repo"
    else
        log_debug "tur-repo package not available or not required"
    fi

    if pkg_available "code-server"; then
        info "Installing code-server from Termux package"
        pkg_install "code-server" "code-server"
        if command -v code-server >/dev/null 2>&1; then
            info "code-server installed via Termux package"
            echo ""
            info "Start: code-server --auth none"
            return 0
        else
            warn "code-server package install reported success but binary not found"
        fi
    else
        warn "Termux package 'code-server' not available. Falling back to npm install."
    fi

    # Fallback: npm installation
    info "Installing build deps for npm-based install"
    install_pkg_list "code-server-deps" build-essential binutils pkg-config python3 nodejs-lts

    if command -v npm >/dev/null 2>&1; then
        log_file "npm: setting python to python3"
        npm config set python python3 || log_debug "npm config set python failed"

        if run_with_spinner_arr "npm: install code-server (global)" -- npm install -g code-server; then
            info "code-server installed via npm"
            if command -v code-server >/dev/null 2>&1; then
                info "code-server binary detected"
                echo ""
                info "Start: code-server --auth none"
                return 0
            else
                warn "npm reported success but 'code-server' not on PATH. You may need to add npm global bin to PATH."
                FAILED_STEPS+=("code-server: npm bin missing from PATH")
                return 0
            fi
        else
            rc=$?; fail_step "npm install -g code-server failed (exit ${rc})"; return ${rc}
        fi
    else
        fail_step "npm not found; cannot install code-server via npm. Install Node.js first."
        return 1
    fi
}

main "$@"
