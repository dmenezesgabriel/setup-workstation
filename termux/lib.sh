#!/data/data/com.termux/files/usr/bin/bash
# Shared helpers for linux-desktop modular installer
set -uo pipefail

# ====== CONSTANTS & GLOBALS ======
readonly TOTAL_STEPS=${TOTAL_STEPS:-10}
RUN_DIR="${RUN_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
# Repository root is the parent of the termux runtime directory. Put global config files under <repo-root>/config
REPO_ROOT="${REPO_ROOT:-$(cd "${RUN_DIR}/.." && pwd)}"
CONFIG_DIR="${CONFIG_DIR:-${REPO_ROOT}/config}"
LOG_FILE="${LOG_FILE:-${RUN_DIR}/linux-desktop-install.log}"

FAILED_STEPS=()
PYTHON_VER=""
CURRENT_STEP=0
DRY_RUN=${DRY_RUN:-0}
VERBOSE=${VERBOSE:-0}
DEBUG=${DEBUG:-0}

# Persistent failed steps file (used to communicate failures from step scripts back to the orchestrator)
FAILED_FILE="${RUN_DIR}/.failed_steps"

# ====== COLOURS ======
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# ====== LOGGING ======
LOG_MAX_FILES=${LOG_MAX_FILES:-3}
LOG_MAX_SIZE=${LOG_MAX_SIZE:-$((10*1024*1024))}

rotate_logs() {
    local file="$1"
    [ -f "${file}" ] || return 0
    local size
    size=$(wc -c <"${file}" 2>/dev/null || echo 0)
    size=${size//[^0-9]/}
    if [ -z "${size}" ] || [ "${size}" -lt "${LOG_MAX_SIZE}" ]; then
        return 0
    fi
    if [ "${LOG_MAX_FILES}" -le 0 ]; then
        : > "${file}"
        return 0
    fi
    if [ -f "${file}.${LOG_MAX_FILES}" ]; then
        rm -f "${file}.${LOG_MAX_FILES}" 2>/dev/null || true
    fi
    local i
    for (( i=LOG_MAX_FILES-1; i>=1; i-- )); do
        if [ -f "${file}.${i}" ]; then
            mv -f "${file}.${i}" "${file}.$((i+1))" 2>/dev/null || true
        fi
    done
    mv -f "${file}" "${file}.1" 2>/dev/null || true
    : > "${file}"
}

log_file() {
    rotate_logs "${LOG_FILE}" || true
    printf "[%s] %s\n" "$(date '+%H:%M:%S')" "$*" >> "${LOG_FILE}"
}
info()      { echo -e "  ${GREEN}✓${NC} $*";                  log_file "INFO  $*"; }
warn()      { echo -e "  ${YELLOW}⚠${NC} $*";                 log_file "WARN  $*"; }
die()       { echo -e "  ${RED}✗ FATAL:${NC} $*" >&2;         log_file "FATAL $*"; exit 1; }
fail_step() {
    warn "$*"
    # Record to persistent failed file so child scripts can report failures back to the parent
    printf "%s\n" "$*" >> "${FAILED_FILE}" 2>/dev/null || true
    FAILED_STEPS+=("$*")
}

log_debug() {
    [ "${VERBOSE}" = "1" ] && echo -e "  ${CYAN}[DEBUG]${NC} $*"
    log_file "DEBUG $*"
}

# ====== PROGRESS ======
update_progress() {
    # update_progress [label]
    local label="${1:-}"
    CURRENT_STEP=$(( CURRENT_STEP + 1 ))
    local width=20
    # percent as integer
    local percent=$(( CURRENT_STEP * 100 / TOTAL_STEPS ))
    # filled is proportional to CURRENT_STEP/TOTAL_STEPS
    local filled=$(( (CURRENT_STEP * width) / TOTAL_STEPS ))
    if [ "${filled}" -lt 0 ]; then filled=0; fi
    if [ "${filled}" -gt "${width}" ]; then filled=${width}; fi
    local empty=$(( width - filled ))
    local bar=""
    local i
    for (( i=0; i<filled; i++ )); do bar+="${GREEN}█"; done
    bar+="${GRAY}"
    for (( i=0; i<empty; i++ )); do bar+="░"; done
    bar+="${NC}"

    echo ""
    echo -e "${CYAN}📊 PROGRESS: ${WHITE}Step ${CURRENT_STEP}/${TOTAL_STEPS}${NC} ${bar} ${WHITE}${percent}%${NC}"
    if [ -n "${label}" ]; then
        echo -e "${CYAN}▶ ${label}${NC}"
    fi
    echo ""
}

# ====== SPINNER ======
spinner() {
    local pid=$1 message=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' i=0
    while kill -0 "${pid}" 2>/dev/null; do
        i=$(( (i + 1) % 10 ))
        printf "\r  ${YELLOW}⏳${NC} %-52s ${CYAN}${spin:$i:1}${NC}  " "${message}"
        sleep 0.1
    done
    wait "${pid}"; local rc=$?
    if [ "${rc}" -eq 0 ]; then
        printf "\r  ${GREEN}✓${NC} %-55s\n" "${message}"; log_file "OK    ${message}"
    else
        printf "\r  ${RED}✗${NC} %-55s ${RED}(exit ${rc})${NC}\n" "${message}"
        log_file "FAIL  ${message} (exit ${rc})"
    fi
    return "${rc}"
}

# ====== PACKAGE HELPERS ======
pkg_available() {
    local pkg="$1"
    if command -v apt >/dev/null 2>&1; then
        if apt show "${pkg}" >/dev/null 2>&1; then
            return 0
        fi
    fi
    if command -v apt-cache >/dev/null 2>&1; then
        if apt-cache show "${pkg}" >/dev/null 2>&1; then
            return 0
        fi
    fi
    if pkg search "^${pkg}$" 2>/dev/null | sed -n '1p' | grep -q .; then
        return 0
    fi
    return 1
}

pkg_install() {
    local pkg="$1" name="${2:-$1}"
    log_file "pkg install ${pkg}"

    if ! pkg_available "${pkg}"; then
        warn "Package '${pkg}' not found in enabled Termux repositories — skipping."
        FAILED_STEPS+=("pkg not available: ${pkg}")
        return 0
    fi

    if [ "${DRY_RUN}" = "1" ]; then
        log_debug "DRY_RUN: would install package ${pkg}"
        return 0
    fi

    (pkg install -y "${pkg}" >> >(while IFS= read -r line; do log_file "$line"; done) 2>&1) &
    spinner $! "pkg: ${name}"
    rc=$?
    if [ "${rc}" -ne 0 ]; then
        fail_step "pkg install ${pkg} failed (exit ${rc})"
        return ${rc}
    fi
}

pip_install() {
    local name="$1"; shift
    local env_vars=() packages=() past_sep=0
    for arg in "$@"; do
        if [ "${arg}" = "--" ]; then past_sep=1; continue; fi
        [ "${past_sep}" -eq 0 ] && env_vars+=("${arg}") || packages+=("${arg}")
    done
    [ "${#packages[@]}" -eq 0 ] && die "pip_install: no packages after '--' for '${name}'"

    local use_no_build_isolation=0
    local tmp_env=()
    for ev in "${env_vars[@]}"; do
        if printf '%s' "${ev}" | grep -q '^NO_BUILD_ISOLATION='; then
            if [ "${ev#*=}" = "1" ]; then use_no_build_isolation=1; fi
            continue
        fi
        tmp_env+=("${ev}")
    done
    env_vars=("${tmp_env[@]}")

    log_file "pip install env=[${env_vars[*]:-}] build_isolation=${use_no_build_isolation} pkgs=[${packages[*]}]"

    if [ "${DRY_RUN}" = "1" ]; then
        log_debug "DRY_RUN: would pip install ${packages[*]} (env: ${env_vars[*]:-}) build_isolation=${use_no_build_isolation}"
        return 0
    fi

    local build_flag=""
    if [ "${use_no_build_isolation}" -eq 1 ]; then
        build_flag="--no-build-isolation"
    fi

    if [ "${#env_vars[@]}" -gt 0 ]; then
        ( env "${env_vars[@]}" \
            pip3 install ${build_flag} --no-cache-dir "${packages[@]}" \
            >> >(while IFS= read -r line; do log_file "$line"; done) 2>&1 ) &
    else
        ( pip3 install ${build_flag} --no-cache-dir "${packages[@]}" \
            >> >(while IFS= read -r line; do log_file "$line"; done) 2>&1 ) &
    fi
    spinner $! "pip: ${name}"
    rc=$?
    if [ "${rc}" -ne 0 ]; then
        fail_step "pip install ${name} failed (exit ${rc})"
        return ${rc}
    fi
}

install_pkg_list() {
    local group="$1"; shift
    log_file "Installing group: ${group} -> [${*}]"
    [ "${DRY_RUN}" = "1" ] && log_debug "DRY_RUN: would install group ${group}: ${*}" && return 0
    for p in "$@"; do
        pkg_install "${p}"
    done
}

_append_to_rcfiles() {
    local line="$1" marker="$2"
    for rc in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
        grep -q "${marker}" "${rc}" 2>/dev/null && continue
        printf '\n# %s\n%s\n' "${marker}" "${line}" >> "${rc}"
    done
}

install_config() {
    # install_config <src> <dest>
    local src="$1" dest="$2"
    mkdir -p "$(dirname "${dest}")" 2>/dev/null || true
    if [ -f "${dest}" ]; then
        if cmp -s "${src}" "${dest}" 2>/dev/null; then
            log_debug "Config ${dest} already identical, skipping"
            return 0
        else
            cp -a "${dest}" "${dest}.bak.$(date +%s)" 2>/dev/null || true
            log_file "Backed up ${dest} -> ${dest}.bak.$(date +%s)"
        fi
    fi
    if [ "${DRY_RUN}" = "1" ]; then
        log_debug "DRY_RUN: would copy ${src} -> ${dest}"
        return 0
    fi
    cp -a "${src}" "${dest}" || { fail_step "install_config ${src} -> ${dest}"; return 1; }
    log_file "Installed config: ${dest}"
}

show_banner() {
    clear
    # Remove any previous run logs so only the latest execution remains
    for f in "${LOG_FILE}" "${LOG_FILE}".* "${FAILED_FILE}"; do
        [ -f "${f}" ] && rm -f "${f}" 2>/dev/null || true
    done
    : > "${LOG_FILE}" 2>/dev/null || true

    echo -e "${CYAN}"
    cat <<'BANNER'
    ╔══════════════════════════════════════════════╗
    ║                                              ║
    ║       🚀  TERMUX TERMINAL ENV v1.0  🚀       ║
    ║                                              ║
    ║    Terminal-only development environment     ║
    ║                                              ║
    ╚══════════════════════════════════════════════╝
BANNER
    echo -e "${NC}"
    echo ""
}

parse_args() {
    # Simple arg parsing for main orchestrator
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run) DRY_RUN=1; shift;;
            --verbose) VERBOSE=1; shift;;
            --debug) DEBUG=1; shift;;
            -h|--help)
                cat <<-USAGE

Usage: $0 [options]

Options:
  --dry-run               Show actions without making changes
  --verbose               Print debug messages to stdout (also logged)
  --debug                 Enable shell tracing (set -x)
  -h, --help              Show this help and exit

USAGE
                exit 0
                ;;
            *) break;;
        esac
    done

    if [ "${DEBUG}" = "1" ]; then
        set -x
        log_debug "Shell tracing enabled"
    fi
}

setup_traps() {
    trap 'rc=$?; cmd="$BASH_COMMAND"; log_file "ERR: ${cmd} (exit ${rc})"; FAILED_STEPS+=("ERR: ${cmd} (exit ${rc})")' ERR
    trap 'log_debug "Script exiting with status $?: $LINENO"' EXIT
}

# Utility: run a numbered script and stream output to both console and log
run_step_script() {
    local script="$1"
    local name
    name=$(basename "${script}")
    log_file "Running script: ${script}"

    # advance & display progress from the orchestrator (parent shell)
    update_progress "${name}"

    if [ "${DRY_RUN}" = "1" ]; then
        log_debug "DRY_RUN: would run ${script}"
        return 0
    fi

    # Prefer stdbuf to avoid buffering; fall back if not available
    if command -v stdbuf >/dev/null 2>&1; then
        stdbuf -oL -eL bash "${script}" 2>&1 | tee -a "${LOG_FILE}"
        rc=${PIPESTATUS[0]}
    else
        bash "${script}" 2>&1 | tee -a "${LOG_FILE}"
        rc=${PIPESTATUS[0]:-${PIPESTATUS[0]}}
    fi

    if [ ${rc} -ne 0 ]; then
        fail_step "script ${name} failed (exit ${rc})"
        echo -e "${RED}✗ ${name} failed (exit ${rc})${NC}"
    else
        echo -e "${GREEN}✓ ${name} completed successfully${NC}"
    fi

    # Collect any persistent failed entries produced by the step (child writes to FAILED_FILE)
    if [ -f "${FAILED_FILE}" ]; then
        while IFS= read -r line; do
            [ -z "${line}" ] && continue
            local found=0
            for e in "${FAILED_STEPS[@]:-}"; do
                if [ "${e}" = "${line}" ]; then found=1; break; fi
            done
            if [ "${found}" -eq 0 ]; then
                FAILED_STEPS+=("${line}")
            fi
        done < "${FAILED_FILE}"
        rm -f "${FAILED_FILE}" 2>/dev/null || true
    fi

    echo ""
    return ${rc}
}
