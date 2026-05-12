#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# Estimate RAM required to load a GGUF model for llama.cpp on this device.
# Straightforward, reproducible, conservative estimator (not overengineered).
# Usage: scripts/17-estimate-memory.sh [model-id-or-filename]
# If called with no arg, it will estimate for every model in MODELS_DIR.

ROUTER_DIR="${ROUTER_DIR:-${HOME}/.local/openwebui-llamacpp}"
MODELS_DIR="${MODELS_DIR:-${ROUTER_DIR}/models}"
API_URL="http://127.0.0.1:8080"

# convert bytes to MiB
b2m() {
  # convert bytes to MiB using awk; argument passed as $1
  echo "$1" | awk '{printf "%.2f", $1/1024/1024}'
}

# get system MemAvailable MiB
get_mem_avail_mib() {
  if [ -r /proc/meminfo ]; then
    awk '/MemAvailable:/ {printf "%d", $2/1024}' /proc/meminfo || echo 0
  else
    echo 0
  fi
}

estimate_for() {
  input="$1"
  # If input matches model id in server, query server for meta
  meta_json=""
  if curl -sS "${API_URL}/v1/models" >/dev/null 2>&1; then
    meta_json=$(curl -sS "${API_URL}/v1/models" || true)
  fi

  model_file=""
  model_size_bytes=0
  n_ctx=2048
  n_embd=1024
  n_layer=24

  # try to interpret input as model id present in meta_json
  if [ -n "${meta_json}" ] && printf '%s' "${meta_json}" | grep -q "\"${input}\""; then
    # extract meta.size and meta.n_ctx/n_embd/layers if available
    model_file=$(printf '%s' "${meta_json}" | awk -v id="${input}" 'match($0, id) {print; exit}') || true
  fi

  # if file exists directly
  if [ -f "${input}" ]; then
    model_file="${input}"
    model_size_bytes=$(stat -c%s "${model_file}" 2>/dev/null || stat -f%z "${model_file}" 2>/dev/null || echo 0)
  fi

  # if input is a basename or id matching a file in MODELS_DIR
  if [ -z "${model_file}" ]; then
    # check common filenames
    for f in "${MODELS_DIR}/${input}" "${MODELS_DIR}/${input}.gguf" "${MODELS_DIR}/${input##*/}"; do
      if [ -f "${f}" ]; then
        model_file="${f}"
        model_size_bytes=$(stat -c%s "${model_file}" 2>/dev/null || stat -f%z "${model_file}" 2>/dev/null || echo 0)
        break
      fi
    done
  fi

  # If we still have no file but server meta JSON contains an entry for the id, try to extract meta fields
  if [ -z "${model_file}" ] && [ -n "${meta_json}" ]; then
    # attempt to find object with id equal to input and parse meta fields
    entry=$(printf '%s' "${meta_json}" | awk -v id="${input}" 'BEGIN{RS="\n"} /"id"/ && index($0,id){print; exit}') || true
    # fallback: parse using jq if available
    if command -v jq >/dev/null 2>&1; then
      size=$(printf '%s' "${meta_json}" | jq -r --arg id "$input" '.data[] | select(.id==$id) | .meta.size // empty' 2>/dev/null || true)
      if [ -n "$size" ]; then
        model_size_bytes=$size
      fi
      n_ctx_j=$(printf '%s' "${meta_json}" | jq -r --arg id "$input" '.data[] | select(.id==$id) | .meta.n_ctx // empty' 2>/dev/null || true)
      [ -n "$n_ctx_j" ] && n_ctx=$n_ctx_j
      n_embd_j=$(printf '%s' "${meta_json}" | jq -r --arg id "$input" '.data[] | select(.id==$id) | .meta.n_embd // empty' 2>/dev/null || true)
      [ -n "$n_embd_j" ] && n_embd=$n_embd_j
      n_layer_j=$(printf '%s' "${meta_json}" | jq -r --arg id "$input" '.data[] | select(.id==$id) | .meta.n_layer // empty' 2>/dev/null || true)
      [ -n "$n_layer_j" ] && n_layer=$n_layer_j
    fi
  fi

  # If still no size but file exists in MODELS_DIR, use that
  if [ $model_size_bytes -eq 0 ]; then
    # try find any matching gguf in MODELS_DIR containing input
    fmatch=$(ls -1 ${MODELS_DIR}/*${input}* 2>/dev/null | head -n1 || true)
    if [ -n "$fmatch" ] && [ -f "$fmatch" ]; then
      model_file="$fmatch"
      model_size_bytes=$(stat -c%s "$model_file" 2>/dev/null || stat -f%z "$model_file" 2>/dev/null || echo 0)
    fi
  fi

  # If still zero size, skip
  if [ $model_size_bytes -eq 0 ]; then
    printf "%s: could not determine model file or size for '%s'\n" "$(date -u +%FT%TZ)" "$input"
    return 1
  fi

  model_size_mib=$(printf '%s' "$model_size_bytes" | b2m)

  # Conservative multipliers
  # model_mem ~ model_size * 1.2 (repack + buffers)
  model_mem_mib=$(awk -v s=$model_size_mib 'BEGIN{printf "%.2f", s*1.2}')

  # Estimate KV cache memory: assume per-token kv ~ n_embd * 2 bytes, times n_ctx and some layer factor
  # We'll use: kv_mib = n_ctx * n_embd * 2 * (n_layer/12) / 1024^2 * 1.1
  kv_mib=$(awk -v nctx=$n_ctx -v nemb=$n_embd -v nl=$n_layer 'BEGIN{printf "%.2f", (nctx * nemb * 2 * (nl/12))/1024/1024 * 1.1}')

  # Compute overhead (buffers, compute) conservatively as 256 MiB
  overhead_mib=256

  total_mib=$(awk -v a=$model_mem_mib -v b=$kv_mib -v c=$overhead_mib 'BEGIN{printf "%.2f", a+b+c}')

  mem_avail=$(get_mem_avail_mib)

  printf "Estimate for '%s'\n" "$input"
  printf "  model_file: %s\n" "${model_file}"
  printf "  model_size: %s MiB\n" "${model_size_mib}"
  printf "  assumed params: n_ctx=%s n_embd=%s n_layer=%s\n" "$n_ctx" "$n_embd" "$n_layer"
  printf "  estimated model_mem: %s MiB (model_size*1.2)\n" "$model_mem_mib"
  printf "  estimated kv_mem: %s MiB (approx)\n" "$kv_mib"
  printf "  overhead: %s MiB\n" "$overhead_mib"
  printf "  TOTAL_ESTIMATED: %s MiB\n" "$total_mib"
  printf "  MemAvailable on system: %s MiB\n" "$mem_avail"

  if awk -v t=$total_mib -v m=$mem_avail 'BEGIN{exit !(m>t+128)}'; then
    printf "  => Likely safe to load (room >128 MiB)\n"
  else
    printf "  => WARNING: Not enough available memory to load safely; consider reducing ctx-size or using a smaller model.\n"
  fi
}

main() {
  if [ "${1:-}" = "" ]; then
    # iterate models in MODELS_DIR
    for f in "${MODELS_DIR}"/*.gguf; do
      [ -e "$f" ] || continue
      estimate_for "$f"
      echo
    done
  else
    estimate_for "$1"
  fi
}

main "$@"
