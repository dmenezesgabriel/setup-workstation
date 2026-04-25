#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_SH="${RUN_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/lib.sh"
# shellcheck disable=SC1091
# shellcheck source=../lib.sh
source "${LIB_SH}"

main() {
    echo -e "${PURPLE}Running static checks (ShellCheck)...${NC}"
    echo ""

    if [ "${DRY_RUN}" = "1" ]; then
        log_debug "DRY_RUN: would ensure shellcheck is installed and run checks"
        return 0
    fi

    if ! command -v shellcheck >/dev/null 2>&1; then
        info "shellcheck not found; installing via pkg"
        pkg_install "shellcheck" "ShellCheck"
    else
        log_debug "shellcheck already installed"
    fi

    # Collect files to lint
    local files=("${RUN_DIR}/lib.sh" "${RUN_DIR}/setup.sh" "${RUN_DIR}/installer-monitor.sh")
    local f
    for f in "${RUN_DIR}/scripts"/*.sh; do
        [ -f "${f}" ] || continue
        files+=("${f}")
    done

    info "Running shellcheck on ${#files[@]} files"

    # Run shellcheck and append output to log
    # Run from RUN_DIR so ShellCheck can resolve relative sources
    pushd "${RUN_DIR}" >/dev/null || true
    run_with_spinner_arr "shellcheck" -- shellcheck -x -s bash "${files[@]}"
    rc=$?
    popd >/dev/null || true
    if [ "${rc}" -ne 0 ]; then
        warn "ShellCheck reported issues (exit ${rc}); see ${LOG_FILE} for details"
        return "${rc}"
    fi
    info "ShellCheck: no issues detected"
}

main "$@"
