#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

CONTAINER_NAME="debian-desktop"
PROOT="/data/data/com.termux/files/usr/bin/proot"
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
        udocker ps 2>/dev/null | grep "$CONTAINER_NAME" | awk '{print $1}'
    fi
}

cmd_start() {
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
        echo "No PID file found. Cleaning up stray processes…"
    fi
    pkill -f "entrypoint.sh" 2>/dev/null || true
    pkill -f "debian-desktop" 2>/dev/null || true
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
