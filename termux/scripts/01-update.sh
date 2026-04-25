#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_SH="${RUN_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/lib.sh"
# shellcheck disable=SC1091
# shellcheck source=../lib.sh
source "${LIB_SH}"

main() {
    local rc
    echo -e "${PURPLE}Updating system packages...${NC}"
    echo ""

    if ! run_with_spinner_arr "Updating package lists..." -- pkg update -y; then
        rc=$?
        fail_step "pkg update failed (exit ${rc})"
    fi

    if ! run_with_spinner_arr "Upgrading installed packages..." -- pkg upgrade -y; then
        rc=$?
        fail_step "pkg upgrade failed (exit ${rc})"
    fi
}

main "$@"
