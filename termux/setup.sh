#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail

# Orchestrator for modular linux-desktop installer
RUN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export RUN_DIR
# shellcheck source=lib.sh
source "${RUN_DIR}/lib.sh"

main() {
    parse_args "$@"
    setup_traps

    show_banner

    echo -e "${WHITE}  Installs a terminal-only development environment (no X11/desktop).${NC}"
    echo ""
    echo -e "${GRAY}  Estimated time: 10-60 min (depends on device)${NC}"
    echo ""
    echo -e "${YELLOW}  Press Enter to start, or Ctrl+C to cancel...${NC}"
    # Only attempt to read from /dev/tty when a TTY is available; otherwise continue
    if [ -t 0 ] && [ -e /dev/tty ]; then
        read -r < /dev/tty || true
    else
        log_debug "No TTY available; continuing non-interactively"
    fi

    # Run scripts in scripts/ in lexical order (prefixed numeric)
    # Iterate the glob directly and guard missing files so we don't accidentally pass
    # a literal pattern when no scripts exist.
    for s in "${RUN_DIR}/scripts"/*.sh; do
        [ -f "${s}" ] || continue
        run_step_script "${s}"
    done

    show_completion
}

get_device_ip() {
    # Try several methods to determine the host's primary IPv4 address
    local ip=''
    if command -v ip >/dev/null 2>&1; then
        ip=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')
    fi
    if [ -z "${ip}" ] && command -v hostname >/dev/null 2>&1; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    if [ -z "${ip}" ] && command -v ifconfig >/dev/null 2>&1; then
        ip=$(ifconfig 2>/dev/null | awk '/inet / && $2!="127.0.0.1" {print $2; exit}')
    fi
    if [ -z "${ip}" ]; then
        ip='127.0.0.1'
    fi
    printf '%s' "${ip}"
}

show_completion() {
    echo ""
    echo -e "${GREEN}"
    cat << 'COMPLETE'
    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║         ✅  INSTALLATION COMPLETE!  ✅                        ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝
COMPLETE
    echo -e "${NC}"

    if [ "${#FAILED_STEPS[@]}" -gt 0 ]; then
        echo -e "${YELLOW}  ⚠  Non-fatal failures (check log for details):${NC}"
        for f in "${FAILED_STEPS[@]}"; do
            echo -e "     ${RED}•${NC} ${f}"
            log_file "NON_FATAL ${f}"
        done
        echo ""
        echo -e "  ${GRAY}Log: ${LOG_FILE}${NC}"
        echo ""
    fi

    echo -e "${WHITE}🛠  Installed/kept:${NC}"
    echo -e "   ${GREEN}git  curl  wget  tmux  vim/neovim  zsh  openssh${NC}"
    echo -e "   ${GREEN}clang  make  cmake  ninja  rust  pkg-config  patchelf${NC}"
    echo -e "   ${GREEN}python  uv  jupyterlab  numpy  pandas  scipy  scikit-learn${NC}"
    echo -e "   ${GREEN}nodejs  pnpm${NC}"
    echo -e "   ${GREEN}dbt (core + postgres adapter)${NC}"
    echo -e "   ${GREEN}duckdb (system lib installed; python bindings may require manual build)${NC}"
    echo ""
    local device_ip
    device_ip=$(get_device_ip)
    echo -e "${WHITE}🔑 SSH:${NC}    ${GREEN}sshd${NC} (port 8022) · connect: ${GREEN}ssh -p 8022 ${device_ip}${NC}"
    echo ""
    echo -e "${GRAY}Full log: ${LOG_FILE}${NC}"
    echo ""
}

main "$@"
