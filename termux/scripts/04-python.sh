#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_SH="${RUN_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/lib.sh"
source "${LIB_SH}"

main() {
    echo -e "${PURPLE}Installing Python + uv...${NC}"
    echo ""

    pkg_install "python" "Python 3"

    PYTHON_VER=$(python3 -c \
        "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" \
        2>/dev/null || echo "")
    if [ -z "${PYTHON_VER}" ]; then
        warn "Could not detect Python version — defaulting to 3.12 for LDFLAGS."
        PYTHON_VER="3.12"
    fi
    info "Python ${PYTHON_VER} detected"
    log_file "PYTHON_VER=${PYTHON_VER}"

    if [ "${DRY_RUN}" = "1" ]; then
        log_debug "DRY_RUN: would install uv via pkg"
    else
        pkg_install "uv" "uv (Termux package)"
    fi

    export PATH="${HOME}/.local/bin:${PATH}"
    _append_to_rcfiles 'export PATH="$HOME/.local/bin:$PATH"' 'LINUX_TERMINAL_UV_PATH'

    # Monitor uv-src if present (same behaviour as original script)
    if [ -d "${RUN_DIR}/uv-src" ]; then
        if [ -f "${RUN_DIR}/uv-src/target/release/uv" ]; then
            mkdir -p "${HOME}/.local/bin" 2>/dev/null || true
            cp "${RUN_DIR}/uv-src/target/release/uv" "${HOME}/.local/bin/uv" 2>/dev/null || true
            chmod +x "${HOME}/.local/bin/uv" 2>/dev/null || true
            info "uv built and installed from ${RUN_DIR}/uv-src"
        else
            if pgrep -f "cargo" >/dev/null 2>&1; then
                (
                    log_file "uv build monitor: started"
                    while pgrep -f "cargo" >/dev/null 2>&1; do sleep 5; done
                    if [ -f "${RUN_DIR}/uv-src/target/release/uv" ]; then
                        mkdir -p "${HOME}/.local/bin" 2>/dev/null || true
                        cp "${RUN_DIR}/uv-src/target/release/uv" "${HOME}/.local/bin/uv" 2>/dev/null || true
                        chmod +x "${HOME}/.local/bin/uv" 2>/dev/null || true
                        log_file "uv build monitor: built and installed ${HOME}/.local/bin/uv"
                        info "uv build monitor: built and installed ${HOME}/.local/bin/uv"
                    else
                        log_file "uv build monitor: finished but binary not found"
                        warn "uv build monitor: finished but binary not found"
                    fi
                ) &
                info "Started background monitor for uv-source build"
            fi
        fi
    fi
}

main "$@"
