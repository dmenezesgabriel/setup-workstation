#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
#  TERMUX LINUX DESKTOP — Installer
#
#  Installs a full Linux desktop environment on Android via Termux, including:
#    • Choice of desktop (XFCE4 / LXQt / MATE / KDE Plasma)
#    • GPU acceleration: Turnip + Zink for Snapdragon/Adreno (HW accelerated)
#                        swrast/llvmpipe for Exynos/Mali (software fallback)
#    • Developer toolchain: git, vim, tmux, openssh, clang, make, cmake, ninja
#    • Python 3 + uv (astral-sh) + data science stack (numpy, pandas, scipy…)
#    • Node.js + pnpm
#    • Zsh + Oh My Zsh + autosuggestions + syntax-highlighting
#    • Wine / Hangover (Windows app compatibility)
#    • One-click start/stop launcher scripts
#
#  Supported devices: Snapdragon (Adreno GPU — HW accel) and Exynos/Mali (SW)
# =============================================================================
# shellcheck disable=SC2034   # colour vars are referenced via echo -e
set -euo pipefail

# ── CONSTANTS ────────────────────────────────────────────────────────────────

readonly TOTAL_STEPS=15
readonly TERMUX_PREFIX="/data/data/com.termux/files/usr"
readonly TERMUX_BIN="${TERMUX_PREFIX}/bin"
readonly LOG_FILE="${HOME}/linux-desktop-install.log"

# ── MUTABLE GLOBALS ──────────────────────────────────────────────────────────

# Accumulated list of non-fatal step failures; reported in the summary.
FAILED_STEPS=()

# Desktop selection (set by choose_desktop).
DE_CHOICE="1"
DE_NAME="XFCE4"

# GPU driver type (set by detect_device).
GPU_DRIVER="freedreno"

# Python version string e.g. "3.12" (set by step_python, used by step_datascience).
PYTHON_VER=""

CURRENT_STEP=0

# ── COLOURS ──────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# ── LOGGING ──────────────────────────────────────────────────────────────────

log_file() { echo "[$(date '+%H:%M:%S')] $*" >> "${LOG_FILE}"; }
info()      { echo -e "  ${GREEN}✓${NC} $*";                  log_file "INFO  $*"; }
warn()      { echo -e "  ${YELLOW}⚠${NC} $*";                 log_file "WARN  $*"; }
die()       { echo -e "  ${RED}✗ FATAL:${NC} $*" >&2;         log_file "FATAL $*"; exit 1; }
fail_step() { warn "$*"; FAILED_STEPS+=("$*"); }

# ── PROGRESS BAR ─────────────────────────────────────────────────────────────

update_progress() {
    CURRENT_STEP=$(( CURRENT_STEP + 1 ))
    local percent=$(( CURRENT_STEP * 100 / TOTAL_STEPS ))
    local filled=$(( percent / 5 ))
    local empty=$(( 20 - filled ))
    local bar="${GREEN}" i
    for (( i=0; i<filled; i++ )); do bar+="█"; done
    bar+="${GRAY}"
    for (( i=0; i<empty;  i++ )); do bar+="░"; done
    bar+="${NC}"
    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  📊 PROGRESS: ${WHITE}Step ${CURRENT_STEP}/${TOTAL_STEPS}${NC} ${bar} ${WHITE}${percent}%${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# ── SPINNER ──────────────────────────────────────────────────────────────────

# spinner PID "message"
# Waits for PID, animating a braille spinner. Returns the exit code of PID.
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

# ── PACKAGE HELPERS ──────────────────────────────────────────────────────────

# pkg_install PACKAGE [DISPLAY_NAME]
# Non-fatal: failed installs are recorded in FAILED_STEPS.
pkg_install() {
    local pkg="$1" name="${2:-$1}"
    log_file "pkg install ${pkg}"
    (yes | pkg install "${pkg}" -y >> "${LOG_FILE}" 2>&1) &
    spinner $! "pkg: ${name}" || fail_step "pkg install ${pkg} failed"
}

# pip_install "DISPLAY_NAME" [KEY=VAL ...] -- PKG [PKG ...]
# Runs pip with optional environment variable prefix. Non-fatal.
#
# Examples:
#   pip_install "numpy"   MATHLIB=m "LDFLAGS=-lpython3.12" -- numpy
#   pip_install "helpers" -- setuptools wheel packaging
pip_install() {
    local name="$1"; shift
    local env_vars=() packages=() past_sep=0
    for arg in "$@"; do
        if [ "${arg}" = "--" ]; then past_sep=1; continue; fi
        [ "${past_sep}" -eq 0 ] && env_vars+=("${arg}") || packages+=("${arg}")
    done
    [ "${#packages[@]}" -eq 0 ] && die "pip_install: no packages after '--' for '${name}'"
    log_file "pip install env=[${env_vars[*]:-}] pkgs=[${packages[*]}]"
    ( env "${env_vars[@]:-}" \
        pip3 install --no-build-isolation --no-cache-dir "${packages[@]}" \
        >> "${LOG_FILE}" 2>&1 ) &
    spinner $! "pip: ${name}" || fail_step "pip install ${name} failed"
}

# ── PRIVATE HELPERS ──────────────────────────────────────────────────────────

# _append_to_rcfiles LINE MARKER
# Appends LINE to ~/.bashrc and ~/.zshrc unless MARKER is already present.
_append_to_rcfiles() {
    local line="$1" marker="$2"
    for rc in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
        grep -q "${marker}" "${rc}" 2>/dev/null && continue
        printf '\n# %s\n%s\n' "${marker}" "${line}" >> "${rc}"
    done
}

# _write_desktop PATH NAME COMMENT EXEC ICON CATEGORIES
_write_desktop() {
    local path="$1" name="$2" comment="$3" exec_val="$4" icon="$5" cats="$6"
    cat > "${path}" << DEOF
[Desktop Entry]
Name=${name}
Comment=${comment}
Exec=${exec_val}
Icon=${icon}
Type=Application
Categories=${cats}
DEOF
}

# ── BANNER ───────────────────────────────────────────────────────────────────

show_banner() {
    clear
    : > "${LOG_FILE}"
    echo -e "${CYAN}"
    cat << 'BANNER'
    ╔══════════════════════════════════════════════╗
    ║                                              ║
    ║       🚀  TERMUX LINUX DESKTOP v2.0  🚀      ║
    ║                                              ║
    ║      Full desktop environment for Android    ║
    ║                                              ║
    ╚══════════════════════════════════════════════╝
BANNER
    echo -e "${NC}"
    echo -e "  ${GRAY}Install log: ${LOG_FILE}${NC}"
    echo ""
}

# ── DEVICE DETECTION ─────────────────────────────────────────────────────────

detect_device() {
    echo -e "${PURPLE}[*] Detecting device...${NC}"
    echo ""

    local model brand android_ver cpu_abi chipset gpu_vendor
    model=$(getprop ro.product.model           2>/dev/null || echo "Unknown")
    brand=$(getprop ro.product.brand           2>/dev/null || echo "Unknown")
    android_ver=$(getprop ro.build.version.release 2>/dev/null || echo "Unknown")
    cpu_abi=$(getprop ro.product.cpu.abi       2>/dev/null || echo "arm64-v8a")
    chipset=$(getprop ro.hardware.chipname     2>/dev/null || echo "")
    gpu_vendor=$(getprop ro.hardware.egl       2>/dev/null || echo "")

    echo -e "  ${GREEN}📱${NC} Device:  ${WHITE}${brand} ${model}${NC}"
    echo -e "  ${GREEN}🤖${NC} Android: ${WHITE}${android_ver}${NC}"
    echo -e "  ${GREEN}⚙️${NC}  CPU:     ${WHITE}${cpu_abi}${NC}"
    log_file "Device: ${brand} ${model} | Android ${android_ver} | CPU ${cpu_abi}"
    log_file "Chipset: ${chipset:-<empty>} | GPU EGL: ${gpu_vendor:-<empty>}"

    # ─────────────────────────────────────────────────────────────────────────
    # GPU DRIVER DECISION
    #
    # Snapdragon  → Qualcomm Adreno GPU
    #   Stack: Zink (GL over Vulkan) → Turnip (open-source Adreno Vulkan) → HW
    #   Turnip supports Adreno 6xx/7xx (SD845+). Older Adreno 5xx: swrast only.
    #
    # Exynos / other → ARM Mali (or unknown)
    #   No open-source Mali Vulkan driver for unprivileged Termux exists.
    #   Falls back to llvmpipe CPU renderer via swrast. Much slower.
    #   XFCE4 or LXQt strongly recommended on these devices.
    #
    # Detection order:
    #   1. ro.hardware.egl   ("adreno" / "mali") — most reliable
    #   2. ro.hardware.chipname  ("sm*" = Snapdragon; "exynos*"/"s5e*" = Exynos)
    #   3. Unknown → assume Adreno (majority of global Android devices)
    # ─────────────────────────────────────────────────────────────────────────
    if   [[ "${gpu_vendor}" == *"adreno"*  ]] \
      || [[ "${chipset}"    == *"sm"*      ]] \
      || [[ "${chipset}"    == *"kalama"*  ]] \
      || [[ "${chipset}"    == *"taro"*    ]] \
      || [[ "${chipset}"    == *"lahaina"* ]]; then
        GPU_DRIVER="freedreno"
        echo -e "  ${GREEN}🎮${NC} GPU: ${WHITE}Adreno (Snapdragon) — Turnip + Zink HW acceleration ✓${NC}"
    elif [[ "${chipset}"    == *"exynos"*  ]] \
      || [[ "${chipset}"    == *"s5e"*     ]] \
      || [[ "${gpu_vendor}" == *"mali"*    ]]; then
        GPU_DRIVER="swrast"
        echo -e "  ${YELLOW}🎮${NC} GPU: ${WHITE}Mali (Exynos) — software rendering (Turnip unavailable)${NC}"
        echo -e "  ${YELLOW}     ⚠  XFCE or LXQt strongly recommended on this device.${NC}"
    else
        GPU_DRIVER="freedreno"
        echo -e "  ${YELLOW}🎮${NC} GPU: ${WHITE}Unknown chipset — assuming Adreno/Turnip${NC}"
        echo -e "  ${YELLOW}     ℹ  If rendering is broken, edit ~/.config/linux-desktop-gpu.sh${NC}"
        echo -e "  ${YELLOW}        and change GALLIUM_DRIVER to swrast.${NC}"
    fi

    log_file "GPU_DRIVER=${GPU_DRIVER}"
    echo ""
    sleep 1
}

# ── DESKTOP SELECTION ────────────────────────────────────────────────────────

choose_desktop() {
    echo -e "${CYAN}📺 Choose your Desktop Environment:${NC}"
    echo ""
    echo -e "  ${WHITE}1) XFCE4${NC}       ${GREEN}(Recommended)${NC} — lightweight, macOS-style dock"
    echo -e "  ${WHITE}2) LXQt${NC}        — ultra-lightweight; best for Exynos / low-RAM"
    echo -e "  ${WHITE}3) MATE${NC}        — classic GNOME 2 style, moderately heavy"
    echo -e "  ${WHITE}4) KDE Plasma${NC}  — modern ${YELLOW}(heavy — GPU + 4 GB RAM recommended)${NC}"
    echo ""
    [ "${GPU_DRIVER}" = "swrast" ] && {
        echo -e "  ${YELLOW}💡 Software rendering detected. XFCE or LXQt are much smoother.${NC}"
        echo ""
    }

    local input
    while true; do
        read -r -p "  Enter number (1-4) [default: 1]: " input < /dev/tty
        input="${input:-1}"
        [[ "${input}" =~ ^[1-4]$ ]] && { DE_CHOICE="${input}"; break; }
        echo "  Invalid choice — please enter 1, 2, 3, or 4."
    done

    case "${DE_CHOICE}" in
        1) DE_NAME="XFCE4";;
        2) DE_NAME="LXQt";;
        3) DE_NAME="MATE";;
        4) DE_NAME="KDE Plasma";;
    esac

    echo ""
    echo -e "  ${GREEN}✓ Selected: ${WHITE}${DE_NAME}${NC}"
    log_file "DE_CHOICE=${DE_CHOICE} DE_NAME=${DE_NAME}"
    echo ""
    sleep 1
}

# ── STEP 1: UPDATE ───────────────────────────────────────────────────────────

step_update() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Updating system packages...${NC}"
    echo ""
    (yes | pkg update  -y >> "${LOG_FILE}" 2>&1) & spinner $! "Updating package lists..."
    (yes | pkg upgrade -y >> "${LOG_FILE}" 2>&1) & spinner $! "Upgrading installed packages..."
}

# ── STEP 2: REPOSITORIES ─────────────────────────────────────────────────────

step_repos() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Adding package repositories...${NC}"
    echo ""
    # x11-repo  → termux-x11-nightly, xorg-xrandr, mesa packages
    # tur-repo  → firefox, code-oss, python-pandas, python-scipy
    pkg_install "x11-repo" "X11 repository"
    pkg_install "tur-repo" "TUR repository (Firefox, VS Code, pandas, scipy)"
}

# ── STEP 3: TERMUX-X11 ───────────────────────────────────────────────────────

step_x11() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Termux-X11...${NC}"
    echo ""
    pkg_install "termux-x11-nightly" "Termux-X11 display server"
    pkg_install "xorg-xrandr"        "xrandr (display settings)"
}

# ── STEP 4: DESKTOP ENVIRONMENT ──────────────────────────────────────────────

step_desktop() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing ${DE_NAME}...${NC}"
    echo ""
    case "${DE_CHOICE}" in
        1)
            pkg_install "xfce4"                    "XFCE4 desktop"
            pkg_install "xfce4-terminal"           "XFCE4 terminal"
            pkg_install "xfce4-whiskermenu-plugin" "Whisker menu"
            pkg_install "plank-reloaded"           "Plank dock (macOS style)"
            pkg_install "thunar"                   "Thunar file manager"
            pkg_install "mousepad"                 "Mousepad editor"
            ;;
        2)
            pkg_install "lxqt"       "LXQt desktop"
            pkg_install "qterminal"  "QTerminal"
            pkg_install "pcmanfm-qt" "PCManFM-Qt file manager"
            pkg_install "featherpad" "FeatherPad editor"
            ;;
        3)
            pkg_install "mate"          "MATE desktop"
            pkg_install "mate-tweak"    "MATE Tweak"
            pkg_install "mate-terminal" "MATE terminal"
            pkg_install "plank-reloaded" "Plank dock"
            ;;
        4)
            pkg_install "plasma-desktop" "KDE Plasma desktop"
            pkg_install "konsole"        "Konsole terminal"
            pkg_install "dolphin"        "Dolphin file manager"
            ;;
    esac
}

# ── STEP 5: GPU DRIVERS ──────────────────────────────────────────────────────

step_gpu() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing GPU drivers (Turnip + Zink)...${NC}"
    echo ""
    # mesa-zink: OpenGL-over-Vulkan; used by all Termux X11 DEs.
    pkg_install "mesa-zink" "Mesa Zink (OpenGL over Vulkan)"
    if [ "${GPU_DRIVER}" = "freedreno" ]; then
        # Turnip: open-source Adreno Vulkan driver. Zink layers on top of this.
        pkg_install "mesa-vulkan-icd-freedreno" "Turnip Adreno Vulkan driver"
    else
        # llvmpipe: CPU-based software Vulkan. Used when Turnip is unavailable.
        pkg_install "mesa-vulkan-icd-swrast" "llvmpipe software Vulkan renderer"
    fi
    pkg_install "vulkan-loader-android" "Vulkan loader"
}

# ── STEP 6: AUDIO ────────────────────────────────────────────────────────────

step_audio() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing audio...${NC}"
    echo ""
    pkg_install "pulseaudio" "PulseAudio"
}

# ── STEP 7: CORE APPLICATIONS + TOOLCHAIN ────────────────────────────────────

step_apps() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing applications and build toolchain...${NC}"
    echo ""

    # ── Productivity / browsers ──────────────────────────────────────────────
    pkg_install "firefox"  "Firefox"
    pkg_install "code-oss" "VS Code (code-oss)"
    pkg_install "vlc"      "VLC media player"

    # ── Shell + dev tools ────────────────────────────────────────────────────
    pkg_install "git"     "git"
    pkg_install "curl"    "curl"
    pkg_install "wget"    "wget"
    pkg_install "tmux"    "tmux"
    pkg_install "vim"     "vim"
    pkg_install "zsh"     "zsh"
    pkg_install "openssh" "OpenSSH (client + server)"

    # ── C/C++ build toolchain ────────────────────────────────────────────────
    # build-essential: Termux meta-package → clang + make + binutils.
    #   Clang is the system compiler in Termux; gcc is not separately packaged
    #   in the main repo (available via tur-repo as gcc-14 if needed).
    #   This is the correct Termux equivalent of Debian's build-essential.
    # binutils-is-llvm: symlinks llvm-ar/llvm-ranlib as "ar"/"ranlib".
    #   Required for building numpy, scipy, and most compiled pip extensions.
    # cmake + ninja: build system used by numpy, pandas, scipy, scikit-learn.
    # pkg-config: needed by matplotlib and other native extension builds.
    # patchelf: fixes RPATH in compiled .so files; required by some pip builds.
    # libandroid-execinfo: provides backtrace() missing from Android's bionic
    #   libc. Required by numpy's crash handler and some scipy modules.
    # NOTE: "python-dev" does NOT exist as a separate package in current Termux.
    #   CPython headers are bundled with the main "python" package itself.
    pkg_install "build-essential"     "build-essential (clang + make + binutils)"
    pkg_install "binutils-is-llvm"    "binutils-is-llvm (llvm-ar as ar/ranlib)"
    pkg_install "cmake"               "cmake"
    pkg_install "ninja"               "ninja"
    pkg_install "pkg-config"          "pkg-config"
    pkg_install "patchelf"            "patchelf"
    pkg_install "libandroid-execinfo" "libandroid-execinfo (backtrace for numpy)"
}

# ── STEP 8: PYTHON + UV ──────────────────────────────────────────────────────

step_python() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Python + uv...${NC}"
    echo ""

    # Termux ships one Python version at a time (currently 3.12).
    # The package includes pip AND the CPython headers; no separate python-dev.
    # CRITICAL: do NOT run "pip install --upgrade pip" — Termux ships a patched
    # pip that handles Android-specific quirks. Upgrading it will break builds.
    pkg_install "python" "Python 3"

    # Detect the installed Python minor version for LDFLAGS in data science step.
    PYTHON_VER=$(python3 -c \
        "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" \
        2>/dev/null || echo "")
    if [ -z "${PYTHON_VER}" ]; then
        warn "Could not detect Python version — defaulting to 3.12 for LDFLAGS."
        PYTHON_VER="3.12"
    fi
    info "Python ${PYTHON_VER} detected"
    log_file "PYTHON_VER=${PYTHON_VER}"

    # uv: official standalone installer. Does not use pip; manages its own
    # binary at ~/.local/bin/uv. The recommended installation method.
    (curl -LsSf https://astral.sh/uv/install.sh | sh >> "${LOG_FILE}" 2>&1) &
    spinner $! "uv standalone installer (astral-sh)"

    export PATH="${HOME}/.local/bin:${PATH}"
    _append_to_rcfiles 'export PATH="$HOME/.local/bin:$PATH"' 'LINUX_DESKTOP_UV_PATH'
}

# ── STEP 9: NODE.JS + PNPM ───────────────────────────────────────────────────

step_node() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Node.js + pnpm...${NC}"
    echo ""

    pkg_install "nodejs" "Node.js"

    # pnpm: official standalone installer. Does not require npm.
    (curl -fsSL https://get.pnpm.io/install.sh | sh - >> "${LOG_FILE}" 2>&1) &
    spinner $! "pnpm standalone installer"

    export PNPM_HOME="${HOME}/.local/share/pnpm"
    export PATH="${PNPM_HOME}:${PATH}"
    _append_to_rcfiles \
        'export PNPM_HOME="$HOME/.local/share/pnpm"; export PATH="$PNPM_HOME:$PATH"' \
        'LINUX_DESKTOP_PNPM_PATH'
}

# ── STEP 10: ZSH + OH MY ZSH ─────────────────────────────────────────────────

step_zsh() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Oh My Zsh + plugins...${NC}"
    echo ""

    local omz_dir="${HOME}/.oh-my-zsh"
    local zshrc="${HOME}/.zshrc"

    # Remove any previous installation so the script is safely re-runnable.
    rm -rf "${omz_dir}" 2>/dev/null || true

    # Install Oh My Zsh unattended.
    #   RUNZSH=no  → do not exec zsh at the end of the install script
    #   CHSH=no    → skip the installer's own chsh call (we do it below with
    #                the Termux-correct form: "chsh -s zsh", short name only)
    # SECURITY NOTE: pipes a remote shell script into sh.
    #   Source: https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh
    #   Review before running if you have supply-chain concerns.
    (
        RUNZSH=no CHSH=no \
        curl -fsSL \
            https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh \
            | sh >> "${LOG_FILE}" 2>&1
    ) &
    spinner $! "Oh My Zsh installer"

    # Clone community plugins.
    local custom_dir="${omz_dir}/custom/plugins"
    mkdir -p "${custom_dir}"

    (git clone --depth=1 \
        https://github.com/zsh-users/zsh-autosuggestions \
        "${custom_dir}/zsh-autosuggestions" >> "${LOG_FILE}" 2>&1) &
    spinner $! "plugin: zsh-autosuggestions"

    (git clone --depth=1 \
        https://github.com/zsh-users/zsh-syntax-highlighting \
        "${custom_dir}/zsh-syntax-highlighting" >> "${LOG_FILE}" 2>&1) &
    spinner $! "plugin: zsh-syntax-highlighting"

    # ── Patch the generated .zshrc ────────────────────────────────────────────
    if [ -f "${zshrc}" ]; then
        sed -i 's|^ZSH_THEME=.*|ZSH_THEME="robbyrussell"|' "${zshrc}"
        sed -i 's|^plugins=(.*|plugins=(git zsh-autosuggestions zsh-syntax-highlighting)|' \
            "${zshrc}"
        info ".zshrc patched (theme: robbyrussell, plugins enabled)"
    else
        warn "~/.zshrc not found — creating minimal config."
        cat > "${zshrc}" << 'MINZSH'
export ZSH="${HOME}/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source "${ZSH}/oh-my-zsh.sh"
MINZSH
    fi

    # PATH block (idempotent via marker)
    if ! grep -q 'LINUX_DESKTOP_ZSH_PATHS' "${zshrc}" 2>/dev/null; then
        cat >> "${zshrc}" << 'ZSHPATHS'

# ── Linux Desktop: PATH ──────────────────────────────── LINUX_DESKTOP_ZSH_PATHS
export PATH="$HOME/.local/bin:$PATH"
export PNPM_HOME="$HOME/.local/share/pnpm"
export PATH="$PNPM_HOME:$PATH"
ZSHPATHS
    fi

    # GPU config (sourced silently; harmless if file absent)
    grep -q 'linux-desktop-gpu.sh' "${zshrc}" 2>/dev/null || \
        echo 'source ~/.config/linux-desktop-gpu.sh 2>/dev/null' >> "${zshrc}"

    # autosuggestions performance (idempotent)
    if ! grep -q 'ZSH_AUTOSUGGEST_USE_ASYNC' "${zshrc}" 2>/dev/null; then
        cat >> "${zshrc}" << 'ZSHAUTO'

# ── Linux Desktop: zsh-autosuggestions ──────────────────────────────────────
ZSH_AUTOSUGGEST_USE_ASYNC=1
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
bindkey '\e[C' autosuggest-accept   # right-arrow accepts suggestion
ZSHAUTO
    fi

    # history (idempotent)
    if ! grep -q 'LINUX_DESKTOP_ZSH_HIST' "${zshrc}" 2>/dev/null; then
        cat >> "${zshrc}" << 'ZSHHIST'

# ── Linux Desktop: history ──────────────────────────── LINUX_DESKTOP_ZSH_HIST
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=10000
export SAVEHIST=10000
setopt SHARE_HISTORY
ZSHHIST
    fi

    # ── Set zsh as the default Termux shell ───────────────────────────────────
    # "chsh -s zsh" (short name, no full path) is the correct form on Termux.
    # The OMZ installer itself uses this exact form in its Termux code path.
    if chsh -s zsh >> "${LOG_FILE}" 2>&1; then
        info "Default shell set to zsh"
    else
        warn "chsh -s zsh failed — run it manually: chsh -s zsh"
    fi
}

# ── STEP 11: DATA SCIENCE STACK ──────────────────────────────────────────────

step_datascience() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Python data science stack...${NC}"
    echo ""

    # ── Why pkg instead of pip for the core stack? ────────────────────────────
    # numpy, pandas, scipy, and matplotlib all require native C/Fortran
    # extensions. A plain "pip install numpy" fails on Termux because pip
    # cannot automatically locate the correct linker flags for Android's bionic
    # libc and Termux's non-standard prefix.
    #
    # Termux maintains patched, pre-compiled packages for these in its repos:
    #   • python-numpy  → main repo
    #   • python-pandas → tur-repo  (enabled in step_repos)
    #   • python-scipy  → main repo
    #   • matplotlib    → main repo (package name is "matplotlib", not "python-matplotlib")
    #
    # Always use "pkg install python-<n>" over "pip install <n>" for these.
    # Source: termux/termux-packages discussions #19126 and #25247.
    #
    # Install order matters: libopenblas must precede numpy; numpy must precede
    # pandas, scipy, and scikit-learn.

    # Native library dependencies
    pkg_install "libopenblas" "OpenBLAS (BLAS/LAPACK for numpy/scipy)"
    pkg_install "fftw"        "FFTW (used by scipy.fft)"

    # Pre-compiled Python packages from Termux repos
    pkg_install "python-numpy"  "NumPy  (pkg — pre-compiled)"
    pkg_install "python-pandas" "pandas (pkg — pre-compiled, tur-repo)"
    pkg_install "python-scipy"  "SciPy  (pkg — pre-compiled)"
    pkg_install "matplotlib"    "Matplotlib (pkg — pre-compiled)"

    # ── Python build helpers for pip source builds ────────────────────────────
    # These are pure-Python and install cleanly.
    pip_install "Python build tools" -- \
        setuptools wheel packaging \
        pyproject_metadata meson-python \
        cython versioneer setuptools-scm

    # ── scikit-learn via pip ──────────────────────────────────────────────────
    # scikit-learn is not in the Termux pkg repos. Build it from source with
    # the required flags:
    #   MATHLIB=m            → link libm (Android bionic needs this explicitly)
    #   LDFLAGS=-lpythonX.Y  → link the Python shared library so native
    #                          extensions can find it at runtime.
    #   --no-build-isolation → re-uses system cmake/ninja/patchelf from pkg
    #                          instead of pip downloading its own copies.
    local ldflags="-lpython${PYTHON_VER}"
    pip_install "scikit-learn" \
        "MATHLIB=m" "LDFLAGS=${ldflags}" -- \
        scikit-learn

    # ── Additional packages (pure-Python or cleanly pip-buildable) ────────────
    pip_install "Jupyter / JupyterLab" -- \
        jupyterlab ipykernel ipywidgets

    pip_install "data utilities" -- \
        sympy plotly tqdm polars pyarrow

    pip_install "ML utilities" -- \
        joblib threadpoolctl

    info "Data science stack installed."
    echo ""
    echo -e "  ${YELLOW}⚠  IMPORTANT: do NOT run 'pip install --upgrade pip'.${NC}"
    echo -e "  ${YELLOW}     Termux ships a patched pip; upgrading it breaks native builds.${NC}"
}

# ── STEP 12: WINE / HANGOVER ─────────────────────────────────────────────────

step_wine() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Wine / Hangover...${NC}"
    echo ""

    (yes | pkg remove wine-stable -y >> "${LOG_FILE}" 2>&1) &
    spinner $! "Removing legacy wine-stable (if present)..."

    pkg_install "hangover-wine"     "Wine/Hangover compatibility layer"
    pkg_install "hangover-wowbox64" "Box64 wrapper"

    # Symlink wine binaries into the standard Termux bin directory.
    ln -sf "${TERMUX_PREFIX}/opt/hangover-wine/bin/wine"    "${TERMUX_BIN}/wine"    2>/dev/null || true
    ln -sf "${TERMUX_PREFIX}/opt/hangover-wine/bin/winecfg" "${TERMUX_BIN}/winecfg" 2>/dev/null || true
    info "Wine symlinks created"

    # Enable font smoothing in the Wine registry (affects ~/.wine only; no host impact).
    wine reg add "HKEY_CURRENT_USER\Control Panel\Desktop" \
        /v FontSmoothing /t REG_SZ /d 2 /f >> "${LOG_FILE}" 2>&1 || true
    info "Wine font smoothing configured"
}

# ── STEP 13: LAUNCHER SCRIPTS ────────────────────────────────────────────────

step_launchers() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Creating launcher scripts...${NC}"
    echo ""

    mkdir -p "${HOME}/.config"

    # XDG paths required so DEs can find icons, themes, and app data.
    local xdg_inject="export XDG_DATA_DIRS=${TERMUX_PREFIX}/share:\${XDG_DATA_DIRS:-}
export XDG_CONFIG_DIRS=${TERMUX_PREFIX}/etc/xdg:\${XDG_CONFIG_DIRS:-}"

    # KDE injects XDG vars through its own environment hook directory.
    if [ "${DE_CHOICE}" = "4" ]; then
        mkdir -p "${HOME}/.config/plasma-workspace/env"
        printf '#!/data/data/com.termux/files/usr/bin/bash\n%s\n' \
            "${xdg_inject}" \
            > "${HOME}/.config/plasma-workspace/env/xdg_fix.sh"
        chmod +x "${HOME}/.config/plasma-workspace/env/xdg_fix.sh"
    fi

    # ── GPU environment file ──────────────────────────────────────────────────
    # Sourced by both ~/.bashrc and ~/.zshrc.  Edit this file to tune GPU
    # behaviour without touching the rc files directly.
    #
    # GALLIUM_DRIVER=zink              → use Mesa Zink as the OpenGL provider
    # MESA_LOADER_DRIVER_OVERRIDE=zink → force Zink even on legacy GL queries
    # TU_DEBUG=noconform               → skip Vulkan conformance checks (faster)
    # MESA_VK_WSI_PRESENT_MODE=immediate → no adaptive vsync; change to
    #                                       "mailbox" if you see tearing
    # MESA_GL_VERSION_OVERRIDE=4.6     → advertise GL 4.6. Not all features are
    #                                    implemented; remove if apps crash.
    # ZINK_DESCRIPTORS=lazy            → deferred Vulkan descriptor updates
    # MESA_NO_ERROR=1                  → disables GL error checking. Fast but
    #                                    driver bugs become silent hard crashes.
    #                                    Remove when debugging rendering issues.
    cat > "${HOME}/.config/linux-desktop-gpu.sh" << GPUEOF
# linux-desktop-gpu.sh — GPU Acceleration Config
# Sourced by ~/.bashrc and ~/.zshrc
export MESA_NO_ERROR=1
export MESA_GL_VERSION_OVERRIDE=4.6
export MESA_GLES_VERSION_OVERRIDE=3.2
export GALLIUM_DRIVER=zink
export MESA_LOADER_DRIVER_OVERRIDE=zink
export TU_DEBUG=noconform
export MESA_VK_WSI_PRESENT_MODE=immediate
export ZINK_DESCRIPTORS=lazy
${xdg_inject}
GPUEOF
    [ "${DE_CHOICE}" = "4" ] && \
        echo "export KWIN_COMPOSE=O2ES" >> "${HOME}/.config/linux-desktop-gpu.sh"

    info "GPU config: ~/.config/linux-desktop-gpu.sh"
    _append_to_rcfiles 'source ~/.config/linux-desktop-gpu.sh 2>/dev/null' \
        'LINUX_DESKTOP_GPU'

    # Plank autostart for XFCE4 / MATE.
    if [ "${DE_CHOICE}" = "1" ] || [ "${DE_CHOICE}" = "3" ]; then
        mkdir -p "${HOME}/.config/autostart"
        cat > "${HOME}/.config/autostart/plank.desktop" << 'PLANKEOF'
[Desktop Entry]
Type=Application
Exec=plank
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Plank
PLANKEOF
    else
        rm -f "${HOME}/.config/autostart/plank.desktop" 2>/dev/null || true
    fi

    # ── start-linux-desktop.sh ───────────────────────────────────────────────
    cat > "${HOME}/start-linux-desktop.sh" << 'LAUNCHEREOF'
#!/data/data/com.termux/files/usr/bin/bash
# start-linux-desktop.sh
set -euo pipefail

export XDG_DATA_DIRS=/data/data/com.termux/files/usr/share:${XDG_DATA_DIRS:-}
export XDG_CONFIG_DIRS=/data/data/com.termux/files/usr/etc/xdg:${XDG_CONFIG_DIRS:-}

# ── Detect installed DEs ──────────────────────────────────────────────────────
DESKTOPS=()
declare -A EXEC_CMDS KILL_CMDS

command -v startxfce4      >/dev/null 2>&1 && {
    DESKTOPS+=("XFCE4")
    EXEC_CMDS["XFCE4"]="exec startxfce4"
    KILL_CMDS["XFCE4"]="pkill -9 xfce4-session 2>/dev/null; pkill -9 plank 2>/dev/null"
}
command -v startlxqt        >/dev/null 2>&1 && {
    DESKTOPS+=("LXQt")
    EXEC_CMDS["LXQt"]="exec startlxqt"
    KILL_CMDS["LXQt"]="pkill -9 lxqt-session 2>/dev/null"
}
command -v mate-session      >/dev/null 2>&1 && {
    DESKTOPS+=("MATE")
    EXEC_CMDS["MATE"]="exec mate-session"
    KILL_CMDS["MATE"]="pkill -9 mate-session 2>/dev/null; pkill -9 plank 2>/dev/null"
}
command -v startplasma-x11  >/dev/null 2>&1 && {
    DESKTOPS+=("KDE Plasma")
    EXEC_CMDS["KDE Plasma"]="(sleep 5 && pkill -9 plasmashell && plasmashell) >/dev/null 2>&1 & exec startplasma-x11"
    KILL_CMDS["KDE Plasma"]="pkill -9 startplasma-x11 2>/dev/null; pkill -9 kwin_x11 2>/dev/null; pkill -9 plasmashell 2>/dev/null"
}

[ ${#DESKTOPS[@]} -eq 0 ] && {
    echo "❌ No desktop environment found. Run setup-linux-desktop.sh first."
    exit 1
}

# ── Select DE ─────────────────────────────────────────────────────────────────
SELECTED_DE=""
if [ ${#DESKTOPS[@]} -eq 1 ]; then
    SELECTED_DE="${DESKTOPS[0]}"
else
    echo "📺 Installed desktops:"
    for i in "${!DESKTOPS[@]}"; do echo "  $((i+1))) ${DESKTOPS[$i]}"; done
    echo ""
    while true; do
        read -r -p "Enter number (1-${#DESKTOPS[@]}): " sel
        [[ "${sel}" =~ ^[0-9]+$ ]] \
            && [ "${sel}" -ge 1 ] \
            && [ "${sel}" -le "${#DESKTOPS[@]}" ] \
            && { SELECTED_DE="${DESKTOPS[$((sel-1))]}"; break; }
        echo "Invalid."
    done
fi

echo ""
echo "🚀 Starting ${SELECTED_DE}..."
source ~/.config/linux-desktop-gpu.sh 2>/dev/null

# ── Cleanup previous session ──────────────────────────────────────────────────
echo "🔄 Cleaning up..."
pkill -9 -f "termux.x11" 2>/dev/null || true
eval "${KILL_CMDS[${SELECTED_DE}]}" || true

# Kill only our own dbus session (avoids broad "pkill -f dbus").
if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    dbus_pid=$(echo "${DBUS_SESSION_BUS_ADDRESS}" | grep -o 'pid=[0-9]*' | cut -d= -f2 || true)
    [ -n "${dbus_pid}" ] && kill "${dbus_pid}" 2>/dev/null || true
fi

# ── Audio ─────────────────────────────────────────────────────────────────────
# PulseAudio TCP is bound to 127.0.0.1 with auth-anonymous=1 (any local
# process can connect). Acceptable in single-user Termux.
unset PULSE_SERVER
pulseaudio --kill 2>/dev/null || true
sleep 0.5
echo "🔊 Starting PulseAudio..."
pulseaudio --start --exit-idle-time=-1
sleep 1
pactl load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 2>/dev/null || true
export PULSE_SERVER=127.0.0.1

# ── Start X11 ─────────────────────────────────────────────────────────────────
echo "📺 Starting Termux-X11..."
termux-x11 :0 -ac &
sleep 3
export DISPLAY=:0

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📱 Open Termux-X11 app to see the desktop!"
echo "  🔊 Audio ready   🎮 GPU acceleration active"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

eval "${EXEC_CMDS[${SELECTED_DE}]}"
LAUNCHEREOF
    chmod +x "${HOME}/start-linux-desktop.sh"
    info "Created ~/start-linux-desktop.sh"

    # ── stop-linux-desktop.sh ────────────────────────────────────────────────
    cat > "${HOME}/stop-linux-desktop.sh" << 'STOPEOF'
#!/data/data/com.termux/files/usr/bin/bash
# stop-linux-desktop.sh
echo "🛑 Stopping Linux Desktop..."
pkill -9 -f "termux.x11"  2>/dev/null || true
pkill -9 -f "pulseaudio"  2>/dev/null || true
pkill -9 xfce4-session    2>/dev/null || true
pkill -9 plank            2>/dev/null || true
pkill -9 lxqt-session     2>/dev/null || true
pkill -9 mate-session     2>/dev/null || true
pkill -9 startplasma-x11  2>/dev/null || true
pkill -9 kwin_x11         2>/dev/null || true
pkill -9 plasmashell      2>/dev/null || true
echo "✓ Done."
STOPEOF
    chmod +x "${HOME}/stop-linux-desktop.sh"
    info "Created ~/stop-linux-desktop.sh"
}

# ── STEP 14: DESKTOP SHORTCUTS ───────────────────────────────────────────────

step_shortcuts() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Creating desktop shortcuts...${NC}"
    echo ""

    mkdir -p "${HOME}/Desktop"

    local term_cmd term_flag
    case "${DE_CHOICE}" in
        1) term_cmd="xfce4-terminal"; term_flag="-e";;
        2) term_cmd="qterminal";       term_flag="-e";;
        3) term_cmd="mate-terminal";   term_flag="-e";;
        4) term_cmd="konsole";         term_flag="-e";;
    esac

    _write_desktop "${HOME}/Desktop/Firefox.desktop" \
        "Firefox" "Web Browser" \
        "firefox" "firefox" "Network;WebBrowser;"

    _write_desktop "${HOME}/Desktop/VSCode.desktop" \
        "VS Code" "Code Editor" \
        "code-oss --no-sandbox" "code-oss" "Development;"

    _write_desktop "${HOME}/Desktop/VLC.desktop" \
        "VLC" "Media Player" \
        "vlc" "vlc" "AudioVideo;"

    _write_desktop "${HOME}/Desktop/Terminal.desktop" \
        "Terminal" "Terminal Emulator" \
        "${term_cmd}" "utilities-terminal" "System;TerminalEmulator;"

    _write_desktop "${HOME}/Desktop/tmux.desktop" \
        "tmux" "Terminal Multiplexer" \
        "${term_cmd} ${term_flag} tmux" "utilities-terminal" "System;TerminalEmulator;"

    _write_desktop "${HOME}/Desktop/JupyterLab.desktop" \
        "JupyterLab" "Interactive Python" \
        "${term_cmd} ${term_flag} jupyter lab --no-browser" \
        "utilities-terminal" "Development;Science;"

    _write_desktop "${HOME}/Desktop/Wine_Config.desktop" \
        "Wine Config" "Windows compatibility" \
        "wine winecfg" "wine" "Settings;"

    # .desktop files are data — 644 is correct, not 755.
    chmod 644 "${HOME}/Desktop/"*.desktop 2>/dev/null || true
    info "Desktop shortcuts created"
}

# ── STEP 15: FINALISE ────────────────────────────────────────────────────────

step_finalize() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Finalising...${NC}"
    echo ""

    chmod 755 "${HOME}/Desktop" 2>/dev/null || true

    # shellcheck source=/dev/null
    source "${HOME}/.config/linux-desktop-gpu.sh" 2>/dev/null || true

    info "All done."
}

# ── COMPLETION SUMMARY ───────────────────────────────────────────────────────

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
        done
        echo ""
        echo -e "  ${GRAY}Log: ${LOG_FILE}${NC}"
        echo ""
    fi

    echo -e "${WHITE}📱 Linux Desktop ready!  (${DE_NAME})${NC}"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${WHITE}🚀 START:${NC}  ${GREEN}bash ~/start-linux-desktop.sh${NC}"
    echo -e "${WHITE}🛑 STOP:${NC}   ${GREEN}bash ~/stop-linux-desktop.sh${NC}"
    echo ""
    echo -e "${WHITE}🔑 SSH:${NC}    ${GREEN}sshd${NC} (port 8022) · connect: ${GREEN}ssh -p 8022 <device-ip>${NC}"
    echo ""
    echo -e "${WHITE}🐍 Data science:${NC}"
    echo -e "   ${GREEN}numpy  pandas  scipy  matplotlib  scikit-learn${NC}"
    echo -e "   ${GREEN}jupyterlab  polars  plotly  sympy  pyarrow  tqdm${NC}"
    echo ""
    echo -e "${WHITE}🛠  Toolchain:${NC}"
    echo -e "   ${GREEN}clang  make  cmake  ninja  git  vim  tmux  zsh (Oh My Zsh)${NC}"
    echo -e "   ${GREEN}uv (Python)  pnpm (Node)  openssh  wine (Hangover)${NC}"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${WHITE}⚡ Open the Termux-X11 app first, then run start-linux-desktop.sh${NC}"
    echo -e "${GRAY}   Full log: ${LOG_FILE}${NC}"
    echo ""
}

# ── MAIN ─────────────────────────────────────────────────────────────────────

main() {
    show_banner

    echo -e "${WHITE}  Installs a full Linux desktop with GPU acceleration.${NC}"
    echo ""
    echo -e "${GRAY}  Estimated time: 30-60 min (data science stack compiles from source)${NC}"
    echo ""
    echo -e "${YELLOW}  Press Enter to start, or Ctrl+C to cancel...${NC}"
    read -r < /dev/tty

    detect_device
    choose_desktop

    step_update       # Step  1 — pkg update + upgrade
    step_repos        # Step  2 — x11-repo + tur-repo
    step_x11          # Step  3 — Termux-X11 + xrandr
    step_desktop      # Step  4 — chosen DE
    step_gpu          # Step  5 — Mesa Zink + Turnip or swrast
    step_audio        # Step  6 — PulseAudio
    step_apps         # Step  7 — git vim tmux zsh openssh + build toolchain
    step_python       # Step  8 — Python 3 + uv
    step_node         # Step  9 — Node.js + pnpm
    step_zsh          # Step 10 — Oh My Zsh + plugins + .zshrc
    step_datascience  # Step 11 — numpy pandas scipy matplotlib sklearn jupyter
    step_wine         # Step 12 — Wine / Hangover
    step_launchers    # Step 13 — start/stop scripts + GPU env file
    step_shortcuts    # Step 14 — .desktop files
    step_finalize     # Step 15 — permissions + source GPU config

    show_completion
}

main
