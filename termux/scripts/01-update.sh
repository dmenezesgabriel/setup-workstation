#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_SH="${RUN_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/lib.sh"
source "${LIB_SH}"

main() {
    echo -e "${PURPLE}Updating system packages...${NC}"
    echo ""

    (pkg update -y >> >(while IFS= read -r line; do log_file "$line"; done) 2>&1) &
    if ! spinner $! "Updating package lists..."; then
        rc=$?
        fail_step "pkg update failed (exit ${rc})"
    fi

    (pkg upgrade -y >> >(while IFS= read -r line; do log_file "$line"; done) 2>&1) &
    if ! spinner $! "Upgrading installed packages..."; then
        rc=$?
        fail_step "pkg upgrade failed (exit ${rc})"
    fi
}

main "$@"
