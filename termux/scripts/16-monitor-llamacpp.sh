#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Simple monitor for the llama.cpp router supervisor and server.
# Usage: scripts/16-monitor-llamacpp.sh [interval_seconds] [iterations]
# Default: interval 10s, iterations 3

INTERVAL=${1:-10}
ITER=${2:-3}
ROUTER_DIR="${ROUTER_DIR:-${HOME}/.local/openwebui-llamacpp}"
LOGFILE="${ROUTER_DIR}/monitor.log"
PIDFILE="${ROUTER_DIR}/run-llama-server.pid"
API_URL="http://127.0.0.1:8080"

printf '# Monitor start: %s\n' "$(date -u +%FT%TZ)" >"${LOGFILE}"
printf 'Interval=%s seconds, Iterations=%s\n' "${INTERVAL}" "${ITER}" >>"${LOGFILE}"

for i in $(seq 1 ${ITER}); do
  ts="$(date -u +%FT%TZ)"
  printf '\n=== ITER %s / %s @ %s ===\n' "$i" "${ITER}" "$ts" | tee -a "${LOGFILE}"

  # Supervisor PID
  if [ -f "${PIDFILE}" ]; then
    sup_pid=$(cat "${PIDFILE}" 2>/dev/null || true)
  else
    sup_pid=""
  fi
  printf 'supervisor_pid=%s\n' "$sup_pid" | tee -a "${LOGFILE}"

  # Processes
  printf '\n-- processes --\n' | tee -a "${LOGFILE}"
  ps aux | rg '[l]lama-server' || true | tee -a "${LOGFILE}"

  # Meminfo snapshot
  printf '\n-- meminfo (top 12 lines) --\n' | tee -a "${LOGFILE}"
  if [ -r /proc/meminfo ]; then
    head -n 12 /proc/meminfo | tee -a "${LOGFILE}"
  fi

  # Check HTTP health
  printf '\n-- HTTP /v1/models --\n' | tee -a "${LOGFILE}"
  models_json=$(curl -sS --max-time 5 ${API_URL}/v1/models || true)
  printf '%s\n' "${models_json}" | tee -a "${LOGFILE}"

  # If a model exists, attempt a very-light generation test (max_tokens=8)
  model_id=""
  if command -v jq >/dev/null 2>&1; then
    model_id=$(printf '%s' "${models_json}" | jq -r '.data[0].id // empty' || true)
  else
    model_id=$(printf '%s' "${models_json}" | sed -n 's/.*"id" *: *"\([^"]\+\)".*/\1/p' | head -n1 || true)
  fi

  if [ -n "${model_id}" ]; then
    printf '\n-- quick generation test (model=%s) --\n' "${model_id}" | tee -a "${LOGFILE}"
    payload=$(printf '{"model":"%s","messages":[{"role":"user","content":"Ping"}],"max_tokens":8}' "${model_id}")
    resp=$(curl -sS --max-time 15 -X POST ${API_URL}/v1/chat/completions -H 'Content-Type: application/json' -d "$payload" || true)
    printf '%s\n' "${resp}" | tee -a "${LOGFILE}"
  else
    printf '\nNo model id detected; skipping generation test\n' | tee -a "${LOGFILE}"
  fi

  printf '\nSleeping %s seconds before next iteration\n' "${INTERVAL}" | tee -a "${LOGFILE}"
  sleep "${INTERVAL}"
done

printf '\n# Monitor end: %s\n' "$(date -u +%FT%TZ)" >>"${LOGFILE}"

# Print summary location
printf '\nMonitor log written to: %s\n' "${LOGFILE}"
exit 0
