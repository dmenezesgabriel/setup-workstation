#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Kill any existing installer-run session to avoid conflicts
if tmux has-session -t installer-run 2>/dev/null; then
  tmux kill-session -t installer-run || true
fi

# Start installer in a detached tmux session
# Use bash -lc inside tmux so the setup script runs in bash and respects the script's shells
tmux new-session -d -s installer-run "bash -lc 'bash termux/setup.sh --verbose'"
# Give tmux a moment to create the session, then send Enter to accept the banner prompt
sleep 0.5
if tmux has-session -t installer-run 2>/dev/null; then
  tmux send-keys -t installer-run Enter
else
  echo "Failed to start tmux session 'installer-run'"
  exit 1
fi

log="termux/linux-desktop-install.log"
# monitor defaults
timeout=600
interval=2
elapsed=0
last=0
printf "Started installer in tmux session 'installer-run'. Monitoring log: %s\n" "${log}"

# Monitor the log for new output and completion markers
while true; do
  if [ -f "${log}" ]; then
    total=$(wc -l < "${log}" 2>/dev/null || echo 0)
    if [ "${total}" -gt "${last}" ]; then
      tail -n $((total - last)) "${log}"
      last=${total}
    fi
  fi

  # Detect common completion markers in the log
  if [ -f "${log}" ] && ( grep -q "All done. Terminal-only environment prepared." "${log}" 2>/dev/null || grep -q "INSTALLATION COMPLETE" "${log}" 2>/dev/null || grep -q "Script exiting with status 0" "${log}" 2>/dev/null ); then
    echo "--- detected completion in log ---"
    break
  fi

  # If the tmux session disappeared, assume the run ended
  if ! tmux has-session -t installer-run 2>/dev/null; then
    echo "--- tmux session ended ---"
    break
  fi

  sleep ${interval}
  elapsed=$((elapsed + interval))
  if [ "${elapsed}" -gt "${timeout}" ]; then
    echo "Timeout reached (${timeout}s); stopping monitor"
    break
  fi

done

# Print a final tail of the log
printf "\nFINAL LOG TAIL (last 200 lines):\n"
if [ -f "${log}" ]; then
  tail -n 200 "${log}"
else
  printf "Log file not found: %s\n" "${log}"
fi
