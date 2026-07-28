#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# ──────────────────────────────────────────────
# setup_termux.sh – one-shot bootstrap for Termux
# Run ONCE on a fresh Termux installation.
# ──────────────────────────────────────────────

LOG="/data/data/com.termux/files/home/.udocker-desktop-setup.log"

info()  { echo "[INFO]  $(date '+%H:%M:%S')  $*" | tee -a "$LOG"; }
warn()  { echo "[WARN]  $(date '+%H:%M:%S')  $*" | tee -a "$LOG"; }
err()   { echo "[ERROR] $(date '+%H:%M:%S')  $*" | tee -a "$LOG"; exit 1; }

XDG_HOME="/data/data/com.termux/files/home"
UDIR="$XDG_HOME/.udocker"
CID_FILE="$XDG_HOME/.udocker-desktop/cid"

mkdir -p "$XDG_HOME/.udocker-desktop"
: > "$LOG"

checkpoint() {
    local step="$1" msg="$2"
    if [ -f "$XDG_HOME/.udocker-desktop/.step_$step" ]; then
        info "SKIP  $msg"
        return 0
    fi
    info "RUN   $msg"
    return 1
}

mark_done() {
    local step="$1"
    : > "$XDG_HOME/.udocker-desktop/.step_$step"
}

# ─── Step 0: Basic environment ──────────────────────────
if ! checkpoint 0 "System packages (python, git)"; then
    apt-get update -y
    # Termux packages: python includes pip; openssh is a separate package
    apt-get install -y python git openssh
    mark_done 0
fi

# ─── Step 1: Install / upgrade udocker ──────────────────
if ! checkpoint 1 "udocker via pip"; then
    python -m pip install --upgrade udocker
    mark_done 1
fi

# ─── Step 2: udocker initial setup ──────────────────────
if ! checkpoint 2 "udocker initial setup"; then
    udocker version
    # Symlink termux proot → .udocker/bin so udocker finds it
    mkdir -p "$UDIR/bin"
    if [ ! -f "$UDIR/bin/proot" ]; then
        ln -sf /data/data/com.termux/files/usr/bin/proot "$UDIR/bin/proot"
    fi
    mark_done 2
fi

# ─── Step 3: Pull & create Debian container ─────────────
CONTAINER_NAME="debian-desktop"
if ! checkpoint 3 "udocker create $CONTAINER_NAME"; then
    info "Pulling and creating Debian container…"
    udocker create --name="$CONTAINER_NAME" debian:bookworm-slim 2>&1 | tee -a "$LOG" || {
        warn "Container creation failed (may already exist). Continuing…"
    }
    mark_done 3
fi

# Get the container ID
CID=$(udocker inspect "$CONTAINER_NAME" 2>/dev/null | python3 -c "
import sys, json
try:
    print(json.load(sys.stdin)[0]['id'])
except Exception:
    sys.exit(1)
" 2>/dev/null) || CID=$(ls -t "$UDIR/containers/" 2>/dev/null | head -1)

if [ -z "$CID" ]; then
    err "Cannot determine container ID. Check udocker ps"
fi
echo "$CID" > "$CID_FILE"
info "Container ID: $CID"

ROOTFS="$UDIR/containers/$CID/ROOT"
if [ ! -d "$ROOTFS" ]; then
    err "ROOTFS directory not found at $ROOTFS"
fi

# ─── Step 4: Fix rootfs permissions ─────────────────────
if ! checkpoint 4 "Fix rootfs permissions"; then
    info "Applying 755 permissions on rootfs…"
    chmod -R 755 "$ROOTFS"
    mark_done 4
fi

# ─── Step 5: Set P1 execution mode ──────────────────────
if ! checkpoint 5 "Set P1 execution mode"; then
    udocker setup --execmode=P1 --force "$CONTAINER_NAME"
    mark_done 5
fi

# ─── Step 6: Enable link2symlink in udocker.conf ────────
if ! checkpoint 6 "Enable proot_link2symlink"; then
    cat > "$UDIR/udocker.conf" << 'UDOCKERCONF'
[DEFAULT]
verbose_level = 1
proot_link2symlink = True
UDOCKERCONF
    mark_done 6
fi

# ─── Step 7: Install desktop packages ───────────────────
if ! checkpoint 7 "Install XFCE + VNC + noVNC"; then
    info "Installing XFCE desktop, x11vnc, noVNC, xvfb… (this takes a while)"
    UDOCKER_USE_PROOT_EXECUTABLE=/data/data/com.termux/files/usr/bin/proot \
    LD_PRELOAD= \
    udocker run --user=root --env=DEBIAN_FRONTEND=noninteractive \
        "$CONTAINER_NAME" \
        apt-get install -y \
            xfce4-session xfce4-panel xfdesktop4 \
            xfce4-settings xfce4-terminal xfwm4 \
            x11vnc novnc xvfb python3-websockify dbus-x11 \
            xdotool scrot imagemagick 2>&1 | tee -a "$LOG"

    # Fix statoverride file if needed (Android /data blocks link())
    if [ -f "$ROOTFS/var/lib/dpkg/statoverride" ]; then
        : > "$ROOTFS/var/lib/dpkg/statoverride"
    fi
    mark_done 7
fi

# ─── Step 8: Write entrypoint.sh inside container ───────
if ! checkpoint 8 "Write entrypoint.sh"; then
    cat > "$ROOTFS/usr/local/bin/entrypoint.sh" << 'ENTRYPOINT'
#!/bin/bash

# proot inherits the host's PATH (Termux), not the container's.
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

DISPLAY="${DISPLAY:-:99}"
RESOLUTION="${RESOLUTION:-1280x720x24}"
VNC_PORT="${VNC_PORT:-5900}"
NOVNC_PORT="${NOVNC_PORT:-6080}"

# Remove stale X locks from previous runs
rm -f "/tmp/.X${DISPLAY#:}-lock" "/tmp/.X11-unix/X${DISPLAY#:}"

echo "entrypoint: Starting Xvfb on $DISPLAY ($RESOLUTION)"
Xvfb "$DISPLAY" -screen 0 "$RESOLUTION" +extension RANDR &
sleep 1

echo "entrypoint: Starting XFCE session"
export DISPLAY="$DISPLAY"
startxfce4 &
sleep 2

echo "entrypoint: Starting x11vnc on port $VNC_PORT (localhost only)"
x11vnc -display "$DISPLAY" -forever -nopw -rfbport "$VNC_PORT" -localhost -noshm -noxdamage -quiet &
sleep 1

# index.html: auto-redirect to noVNC with correct WebSocket port (6080)
cat > /usr/share/novnc/index.html << 'INDEX'
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<meta http-equiv="refresh" content="0;url=vnc.html?host=127.0.0.1&port=6080&autoconnect=1">
</head><body></body></html>
INDEX

echo "entrypoint: Starting noVNC on port $NOVNC_PORT"
exec websockify --web /usr/share/novnc "$NOVNC_PORT" "127.0.0.1:$VNC_PORT"
ENTRYPOINT
    chmod 755 "$ROOTFS/usr/local/bin/entrypoint.sh"
    mark_done 8
fi

# ─── Step 9: Write CLI helper ──────────────────────────
if ! checkpoint 9 "Write termux-docker-desktop.sh"; then
    mkdir -p "$XDG_HOME/.local/bin"
    cat > "$XDG_HOME/.local/bin/termux-docker-desktop.sh" << 'CLIHELPER'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

CONTAINER_NAME="debian-desktop"
PROOT="/data/data/com.termux/files/usr/bin/proot"
PREFIX="LD_PRELOAD= UDOCKER_USE_PROOT_EXECUTABLE=$PROOT"
CID_FILE="$HOME/.udocker-desktop/cid"
PID_FILE="$HOME/.udocker-desktop/container.pid"
LOG_FILE="$HOME/.udocker-desktop/container.log"

usage() {
    cat <<EOF
Usage: termux-docker-desktop.sh <command>

Commands:
  start       Start the desktop container
  stop        Stop the desktop container
  shell       Open a root shell inside the container
  status      Show container status
  logs        Tail the container logs
  rm          Remove the container (must be stopped first)
EOF
    exit 0
}

get_cid() {
    if [ -f "$CID_FILE" ]; then
        cat "$CID_FILE"
    else
        # Fallback: find by name
        udocker ps 2>/dev/null | grep "$CONTAINER_NAME" | awk '{print $1}'
    fi
}

cmd_start() {
    local rm_flag=""
    local publish_args=()
    local volume_args=()
    local remain=()

    while [ $# -gt 0 ]; do
        case "$1" in
            --rm) rm_flag="--rm" ;;
            -p|--publish) publish_args+=("--publish=$2"); shift ;;
            -v|--volume) volume_args+=("--volume=$2"); shift ;;
            --) shift; remain+=("$@"); break ;;
            *) remain+=("$1") ;;
        esac
        shift
    done

    local cid
    cid=$(get_cid)
    if [ -z "$cid" ]; then
        echo "Error: container '$CONTAINER_NAME' not found. Run setup_termux.sh first." >&2
        exit 1
    fi

    echo "Starting desktop container…"

    nohup bash -c \
        "LD_PRELOAD= UDOCKER_USE_PROOT_EXECUTABLE=$PROOT udocker run --user=root \
            --env=DISPLAY=:99 \
            \"$cid\" \
            /usr/local/bin/entrypoint.sh" \
        >> "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"

    echo "Container started (PID $(cat "$PID_FILE"))"
    echo "Access noVNC at http://$HOSTNAME:6080/vnc.html"
    echo "  or via SSH tunnel: ssh -L 6080:localhost:6080 -p 8022 u0_a357@<ip>"
}

cmd_stop() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        kill "$pid" 2>/dev/null && echo "Stopped (PID $pid)" || echo "Not running"
        rm -f "$PID_FILE"
    else
        # Kill any remaining proot/entrypoint processes
        echo "No PID file found. Cleaning up stray processes…"
    fi
    # Kill all proot and udocker processes related to the desktop container
    pkill -f "entrypoint.sh" 2>/dev/null || true
    pkill -f "debian-desktop" 2>/dev/null || true
    # Clean up X locks
    rm -f /tmp/.X*-lock /tmp/.X11-unix/X*
}

cmd_shell() {
    local cid
    cid=$(get_cid)
    if [ -z "$cid" ]; then
        echo "Error: container '$CONTAINER_NAME' not found." >&2
        exit 1
    fi
    # shellcheck disable=SC2086
    eval $PREFIX udocker run --user=root "$cid" /bin/bash
}

cmd_status() {
    local cid
    cid=$(get_cid)
    if [ -z "$cid" ]; then
        echo "Container not found"
        return
    fi
    echo "Container: $CONTAINER_NAME ($cid)"
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Status: running (PID $pid)"
        else
            echo "Status: stopped (stale PID $pid)"
        fi
    else
        echo "Status: not managed (no PID file)"
    fi
}

cmd_logs() {
    if [ -f "$LOG_FILE" ]; then
        tail -f "$LOG_FILE"
    else
        echo "No log file found."
    fi
}

cmd_rm() {
    local cid
    cid=$(get_cid)
    if [ -z "$cid" ]; then
        echo "Container not found"
        return
    fi
    udocker rm "$cid"
    rm -f "$CID_FILE"
    echo "Removed"
}

case "${1:-help}" in
    start)   shift; cmd_start "$@" ;;
    stop)    cmd_stop ;;
    shell)   cmd_shell ;;
    status)  cmd_status ;;
    logs)    cmd_logs ;;
    rm)      cmd_rm ;;
    help|--help|-h) usage ;;
    *)       echo "Unknown command: $1"; usage ;;
esac
CLIHELPER
    chmod 755 "$XDG_HOME/.local/bin/termux-docker-desktop.sh"
    mark_done 9
fi

# ─── Step 10: Add ~/.local/bin to PATH ─────────────────
if ! checkpoint 10 "Add ~/.local/bin to PATH"; then
    BASHRC="$XDG_HOME/.bashrc"
    if ! grep -q '.local/bin' "$BASHRC" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$BASHRC"
    fi
    # zsh
    ZSHRC="$XDG_HOME/.zshrc"
    if [ -f "$ZSHRC" ] && ! grep -q '.local/bin' "$ZSHRC" 2>/dev/null; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$ZSHRC"
    fi
    mark_done 10
fi

# ─── Step 11: Configure X11 environment in container ──────
if ! checkpoint 11 "Configure X11 environment"; then
    info "Configuring X11 environment (DISPLAY, bashrc, profile)…"

    # /etc/environment is read by PAM; helps when DISPLAY is not inherited
    echo "DISPLAY=:99" > "$ROOTFS/etc/environment"

    # Wrapper script — works from menus, .desktop files, and non-interactive shells
    # (Aliases only work in interactive bash, so a real script is needed.)
    cat > "$ROOTFS/usr/local/bin/code-desktop" << 'WRAPPER'
#!/bin/bash
mkdir -p /root/.vscode-data
exec code --no-sandbox --disable-gpu --disable-dev-shm-usage --user-data-dir=/root/.vscode-data "$@"
WRAPPER
    chmod 755 "$ROOTFS/usr/local/bin/code-desktop"

    # .bashrc for interactive terminals spawned by xfce4-terminal
    cat > "$ROOTFS/root/.bashrc" << 'BASHRC'
export DISPLAY=:99
alias code-desktop='code --no-sandbox --disable-gpu --disable-dev-shm-usage --user-data-dir=/root/.vscode-data'
BASHRC

    # .profile for login shells
    cat > "$ROOTFS/root/.profile" << 'PROFILE'
export DISPLAY=:99
PROFILE

    # XFCE desktop launcher for VS Code
    mkdir -p "$ROOTFS/usr/share/applications"
    cat > "$ROOTFS/usr/share/applications/code.desktop" << 'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=VS Code
Comment=Visual Studio Code
Exec=code-desktop
Icon=com.visualstudio.code
Terminal=false
Categories=Development;IDE;
DESKTOP

    mark_done 11
fi

# ─── Step 12: Install VS Code (optional) ─────────────────
if ! checkpoint 12 "Install Visual Studio Code"; then
    info "Installing VS Code for arm64 (this takes a while)…"
    UDOCKER_USE_PROOT_EXECUTABLE=/data/data/com.termux/files/usr/bin/proot \
    LD_PRELOAD= \
    udocker run --user=root --env=DEBIAN_FRONTEND=noninteractive \
        "$CONTAINER_NAME" \
        bash -c '
            apt-get install -y wget gpg && \
            wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
                | gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg && \
            echo "deb [arch=arm64] https://packages.microsoft.com/repos/code stable main" \
                > /etc/apt/sources.list.d/vscode.list && \
            apt-get update -qq && \
            apt-get install -y code
        ' 2>&1 | tee -a "$LOG"

    if [ -f "$ROOTFS/var/lib/dpkg/statoverride" ]; then
        : > "$ROOTFS/var/lib/dpkg/statoverride"
    fi
    mark_done 12
fi

# ─── Step 13: Install OpenCode CLI (optional) ────────────
if ! checkpoint 13 "Install OpenCode CLI"; then
    info "Installing OpenCode (AI coding agent)…"
    UDOCKER_USE_PROOT_EXECUTABLE=/data/data/com.termux/files/usr/bin/proot \
    LD_PRELOAD= \
    udocker run --user=root --env=DEBIAN_FRONTEND=noninteractive \
        "$CONTAINER_NAME" \
        bash -c '
            apt-get install -y -qq curl ca-certificates && \
            curl -fsSL https://opencode.ai/install | bash
        ' 2>&1 | tee -a "$LOG"
    mark_done 13
fi

# ─── Unconditional fixes (applied every run, idempotent) ──
# These can't be gated behind checkpoints because a checkpoint
# that already completed won't re-run if the script is updated.
info "Applying idempotent environment fixes…"

echo "DISPLAY=:99" > "$ROOTFS/etc/environment"

# Re-ensure the wrapper script exists (it's tiny, no cost to rewrite)
cat > "$ROOTFS/usr/local/bin/code-desktop" << 'WRAPPER'
#!/bin/bash
mkdir -p /root/.vscode-data
exec code --no-sandbox --disable-gpu --disable-dev-shm-usage --user-data-dir=/root/.vscode-data "$@"
WRAPPER
chmod 755 "$ROOTFS/usr/local/bin/code-desktop"

# Ensure DISPLAY is in shell profiles
if ! grep -q 'DISPLAY=:99' "$ROOTFS/root/.bashrc" 2>/dev/null; then
    echo "export DISPLAY=:99" >> "$ROOTFS/root/.bashrc"
fi
if ! grep -q 'DISPLAY=:99' "$ROOTFS/root/.profile" 2>/dev/null; then
    echo "export DISPLAY=:99" >> "$ROOTFS/root/.profile"
fi

# Ensure code-desktop alias in .bashrc
if ! grep -q 'code-desktop' "$ROOTFS/root/.bashrc" 2>/dev/null; then
    echo "alias code-desktop='code --no-sandbox --disable-gpu --disable-dev-shm-usage --user-data-dir=/root/.vscode-data'" >> "$ROOTFS/root/.bashrc"
fi

# Symlink opencode into /usr/local/bin so it's always on PATH
# (the installer puts it in ~/.opencode/bin which may not be inherited)
if [ -x "$ROOTFS/root/.opencode/bin/opencode" ]; then
    ln -sf /root/.opencode/bin/opencode "$ROOTFS/usr/local/bin/opencode"
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Setup complete!"
echo ""
echo "  Next steps:"
echo "    1. Restart your shell or run: export PATH=\"\$HOME/.local/bin:\$PATH\""
echo "    2. Start the desktop:  termux-docker-desktop.sh start"
echo "    3. Open in tablet browser: http://localhost:6080/vnc.html"
echo "    4. From another device: ssh -L 6080:localhost:6080 -p 8022 u0_a357@<ip>"
echo "    5. Shell access:        termux-docker-desktop.sh shell"
echo "    6. Stop:                termux-docker-desktop.sh stop"
echo "═══════════════════════════════════════════════════════"
