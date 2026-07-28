#!/bin/bash

# proot inherits the host's PATH (Termux), not the container's.
# Commands won't be found without the container's standard PATH.
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

DISPLAY="${DISPLAY:-:99}"
RESOLUTION="${RESOLUTION:-1280x720x24}"
VNC_PORT="${VNC_PORT:-5900}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
# Clean stale X locks from previous runs (survive container restart)
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
