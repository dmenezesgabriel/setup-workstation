#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_SH="${RUN_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/lib.sh"
source "${LIB_SH}"

main() {
    echo -e "${PURPLE}Finalising...${NC}"
    echo ""

    # Optional GPU config
    if [ -f "${HOME}/.config/linux-desktop-gpu.sh" ]; then
        source "${HOME}/.config/linux-desktop-gpu.sh" 2>/dev/null || true
    fi

    info "All done. Terminal-only environment prepared."
}

main "$@"
