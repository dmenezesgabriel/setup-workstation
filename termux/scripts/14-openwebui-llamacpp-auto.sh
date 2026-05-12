#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_SH="${RUN_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/lib.sh"
# shellcheck disable=SC1091
source "${LIB_SH}"

# Automated, idempotent setup that follows the recommendations.
# - Ensures llama.cpp server exists (builds if needed)
# - Creates presets for .gguf models
# - Maintains a simple manifest with sha256
# - Optionally downloads LiquidAI/LFM2.5-350M-GGUF
# - Creates start/stop helper and alias

ROUTER_DIR="${ROUTER_DIR:-${HOME}/.local/openwebui-llamacpp}"
MODELS_DIR="${MODELS_DIR:-${ROUTER_DIR}/models}"
ROUTER_PORT="${ROUTER_PORT:-8080}"
HF_TOKEN="${HF_TOKEN:-}"
LLAMA_DIR="${LLAMA_DIR:-${HOME}/src/llama.cpp}"
DOWNLOAD_LFM2_5="${DOWNLOAD_LFM2_5:-1}"
MANIFEST_FILE="${MODELS_DIR}/models.json"
BIN_DIR="${HOME}/.local/bin"
START_HELPER="${BIN_DIR}/start-llama-openwebui.sh"

info "Auto setup: ROUTER_DIR=${ROUTER_DIR}, MODELS_DIR=${MODELS_DIR}, LLAMA_DIR=${LLAMA_DIR}"

mkdir -p "${ROUTER_DIR}" "${MODELS_DIR}" "${BIN_DIR}"

# helpers
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    echo ""
  fi
}

load_manifest() {
  if [ -f "${MANIFEST_FILE}" ]; then
    MANIFEST_JSON=$(cat "${MANIFEST_FILE}") || MANIFEST_JSON='{}'
  else
    MANIFEST_JSON='{}'
  fi
}

save_manifest() {
  printf '%s\n' "${MANIFEST_JSON}" > "${MANIFEST_FILE}.tmp" && mv "${MANIFEST_FILE}.tmp" "${MANIFEST_FILE}"
}

find_server_bin() {
  local d="${LLAMA_DIR}/build/bin"
  if [ -d "${d}" ]; then
    for n in server llama-server "llama.cpp-server"; do
      if [ -x "${d}/${n}" ]; then
        printf "%s\n" "${d}/${n}"
        return 0
      fi
    done
    local f
    f=$(find "${d}" -maxdepth 1 -type f -executable -iname "*server*" 2>/dev/null | head -n1 || true)
    if [ -n "${f}" ]; then
      printf "%s\n" "${f}"
      return 0
    fi
  fi
  return 1
}

SERVER_BIN=""
if [ -d "${LLAMA_DIR}" ]; then
  SERVER_BIN=$(find_server_bin || true)
fi

if [ -z "${SERVER_BIN}" ]; then
  warn "llama.cpp server binary not found; attempting a minimal build"
  if [ ! -d "${LLAMA_DIR}" ]; then
    fail_step "llama.cpp not found at ${LLAMA_DIR}; run scripts/12-llamacpp.sh first"
    exit 1
  fi
  cd "${LLAMA_DIR}"
  rm -rf build || true
  cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_TOOLS=ON -DGGML_OPENMP=OFF -DBUILD_SHARED_LIBS=OFF || {
    fail_step "cmake configure for server failed"
    exit 1
  }
  cmake --build build --target server -- -j 1 || cmake --build build --target llama-server -- -j 1 || cmake --build build -- -j 1
  SERVER_BIN=$(find_server_bin || true)
fi

if [ -z "${SERVER_BIN}" ]; then
  fail_step "Could not find/build llama.cpp server binary in ${LLAMA_DIR}/build/bin"
  exit 1
fi

info "Using server binary: ${SERVER_BIN}"

# Create minimal preset JSON files for .gguf files and update manifest
create_presets_and_manifest() {
  load_manifest
  for f in "${MODELS_DIR}"/*.gguf; do
    [ -e "${f}" ] || continue
    base=$(basename "${f}" .gguf)
    preset="${MODELS_DIR}/${base}.json"
    if [ ! -f "${preset}" ]; then
      info "Creating preset: ${preset}"
      cat > "${preset}" <<JSON
{
  "model": "${base}",
  "path": "${base}.gguf",
  "type": "gguf"
}
JSON
    fi
    lp="${MODELS_DIR}/${base}.gguf"
    sha=$(sha256_of "${lp}" || true)
    # update MANIFEST_JSON using jq if available
    if command -v jq >/dev/null 2>&1; then
      MANIFEST_JSON=$(printf '%s' "${MANIFEST_JSON}" | jq --arg k "${base}" --arg p "${lp}" --arg s "${sha}" '.[$k] = {local_path:$p,sha256:$s,added_at:(now|todate)}') || true
    else
      # naive write (best-effort)
      if [ -f "${MANIFEST_FILE}" ]; then
        tmp="$(mktemp)"
        printf '{"%s": {"local_path":"%s","sha256":"%s","added_at":"%s"}}\n' "${base}" "${lp}" "${sha}" "$(date -u +%FT%TZ)" > "${tmp}"
        cat "${MANIFEST_FILE}" >> "${tmp}"
        mv "${tmp}" "${MANIFEST_FILE}"
        MANIFEST_JSON=$(cat "${MANIFEST_FILE}") || MANIFEST_JSON='{}'
      else
        printf '{"%s": {"local_path":"%s","sha256":"%s","added_at":"%s"}}\n' "${base}" "${lp}" "${sha}" "$(date -u +%FT%TZ)" > "${MANIFEST_FILE}"
        MANIFEST_JSON=$(cat "${MANIFEST_FILE}") || MANIFEST_JSON='{}'
      fi
    fi
  done
  save_manifest
}

# Download the LFM2.5-350M model using huggingface_hub for reproducibility
download_lfm2_5() {
  if [ "${DOWNLOAD_LFM2_5}" != "1" ]; then
    info "Skipping LFM2.5-350M download"
    return 0
  fi
  repo="LiquidAI/LFM2.5-350M-GGUF"
  # Use a small venv under router dir to ensure reproducible pinned tooling
  venv="${ROUTER_DIR}/hf-venv"
  if [ ! -x "${venv}/bin/python" ]; then
    info "Creating venv for huggingface_hub at ${venv}"
    python3 -m venv "${venv}"
  fi
  info "Ensuring huggingface-hub is installed inside venv"
  "${venv}/bin/pip" install --upgrade pip >/dev/null 2>&1 || true
  "${venv}/bin/pip" install --no-cache-dir huggingface-hub==0.16.4 >/dev/null 2>&1 || true

  info "Querying Hugging Face for .gguf files in ${repo}"
  # Use python to list files and download the first .gguf; update manifest with provenance
  export HF_DOWNLOAD_REPO="${repo}"
  export HF_MODELS_DIR="${MODELS_DIR}"
  export HF_MANIFEST_FILE="${MANIFEST_FILE}"
  DL_OUT=$("${venv}/bin/python" - <<'PY'
import os,sys,json,hashlib,shutil
from huggingface_hub import HfApi, hf_hub_download
repo = os.environ.get('HF_DOWNLOAD_REPO')
if not repo:
    print('ERROR:NOREPO')
    sys.exit(2)
token = os.environ.get('HF_TOKEN') or None
models_dir = os.environ.get('HF_MODELS_DIR')
manifest_file = os.environ.get('HF_MANIFEST_FILE')
api = HfApi()
try:
    files = api.list_repo_files(repo_id=repo, use_auth_token=token)
except Exception as e:
    print('ERROR:LIST:'+str(e))
    sys.exit(2)
cands = [f for f in files if f.lower().endswith('.gguf')]
if not cands:
    print('ERROR:NO_GGUF')
    sys.exit(3)
fn = cands[0]
try:
    path = hf_hub_download(repo_id=repo, filename=fn, cache_dir=models_dir, token=token)
except Exception as e:
    print('ERROR:DL:'+str(e))
    sys.exit(4)
# copy into models_dir root to have predictable path
dest = os.path.join(models_dir, os.path.basename(path))
if os.path.abspath(path) != os.path.abspath(dest):
    try:
        shutil.copy2(path, dest)
    except Exception:
        dest = path
# compute sha256
h = hashlib.sha256()
with open(dest,'rb') as fh:
    for chunk in iter(lambda: fh.read(8192), b''):
        h.update(chunk)
sha = h.hexdigest()
# update manifest
m = {}
if os.path.exists(manifest_file):
    try:
        with open(manifest_file,'r',encoding='utf-8') as mf:
            m = json.load(mf)
    except Exception:
        m = {}
key = repo + '/' + fn
m[key] = {'repo_id': repo, 'filename': fn, 'revision': None, 'local_path': dest, 'sha256': sha, 'downloaded_at': __import__('datetime').datetime.utcnow().isoformat() + 'Z'}
with open(manifest_file,'w',encoding='utf-8') as mf:
    json.dump(m, mf, indent=2, ensure_ascii=False)
print(dest)
PY
)
  rc=$?
  if [ ${rc} -ne 0 ]; then
    warn "huggingface_hub download failed (code=${rc}): ${DL_OUT}"
    return 1
  fi
  target_path="${DL_OUT}"
  # In case python printed additional info, take last line
  target_path=$(printf '%s' "${DL_OUT}" | tail -n1)
  if [ -f "${target_path}" ]; then
    info "Downloaded model to ${target_path}"
    create_presets_and_manifest
    return 0
  else
    warn "Download succeeded but expected file not found: ${target_path}"
    return 1
  fi
}

# Create launcher
LAUNCH_SH="${ROUTER_DIR}/run-llama-server.sh"
cat > "${LAUNCH_SH}" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
MODELS_DIR="${MODELS_DIR}"
ROUTER_PORT="${ROUTER_PORT}"
SERVER_BIN="${SERVER_BIN}"
HF_TOKEN="${HF_TOKEN}"
exec "${SERVER_BIN}" --router --host 127.0.0.1 --port ${ROUTER_PORT} --models-dir "${MODELS_DIR}" --hf-token "${HF_TOKEN}"
EOF
chmod +x "${LAUNCH_SH}"
info "Wrote launcher: ${LAUNCH_SH}"

# Create start helper
cat > "${START_HELPER}" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROUTER_DIR="${HOME}/.local/openwebui-llamacpp"
LAUNCH_SH="${ROUTER_DIR}/run-llama-server.sh"
LOG="${ROUTER_DIR}/llama-server.log"
case "${1:-start}" in
  start)
    if pgrep -f "$(basename "${LAUNCH_SH}")" >/dev/null 2>&1; then
      echo "llama-server already running"
      exit 0
    fi
    nohup "${LAUNCH_SH}" >"${LOG}" 2>&1 &
    echo "started (logs -> ${LOG})"
    ;;
  stop)
    pkill -f "$(basename "${LAUNCH_SH}")" || true
    echo "stopped"
    ;;
  restart)
    "$0" stop || true
    sleep 1
    "$0" start
    ;;
  status)
    if pgrep -f "$(basename "${LAUNCH_SH}")" >/dev/null 2>&1; then
      echo "running"
    else
      echo "not running"
      exit 1
    fi
    ;;
  *)
    echo "usage: $0 {start|stop|restart|status}"
    exit 2
    ;;
esac
SH
chmod +x "${START_HELPER}"
info "Wrote start helper: ${START_HELPER}"

# Ensure aliases in zshrc for start/stop
ZSHRC="${HOME}/.zshrc"
ALIAS_START="alias owui-start=\"${START_HELPER} start\""
ALIAS_STOP="alias owui-stop=\"${START_HELPER} stop\""
if [ -f "${ZSHRC}" ]; then
  if ! grep -Fq "${ALIAS_START}" "${ZSHRC}"; then
    printf '\n# OpenWebUI helper aliases\n%s\n%s\n' "${ALIAS_START}" "${ALIAS_STOP}" >> "${ZSHRC}"
  fi
else
  printf '%s\n%s\n' "${ALIAS_START}" "${ALIAS_STOP}" > "${ZSHRC}"
fi

# Run tasks
create_presets_and_manifest
download_lfm2_5

# Start server and verify
"${START_HELPER}" start || true
sleep 3
if curl -sS "http://127.0.0.1:${ROUTER_PORT}/v1/models" >/dev/null 2>&1; then
  info "Server listening on http://127.0.0.1:${ROUTER_PORT}"
  MODELS_JSON=$(curl -sS "http://127.0.0.1:${ROUTER_PORT}/v1/models" || true)
  if command -v jq >/dev/null 2>&1; then
    MODEL_ID=$(printf '%s' "${MODELS_JSON}" | jq -r '.data[0].id // .data[0].name // .data[0].model // empty') || true
  else
    MODEL_ID=$(printf '%s' "${MODELS_JSON}" | sed -n 's/.*"id":\s*"\([^"]\+\)".*/\1/p' | head -n1 || true)
  fi
  if [ -n "${MODEL_ID}" ]; then
    PROVIDER_FILE="${ROUTER_DIR}/openwebui-provider.json"
    cat > "${PROVIDER_FILE}" <<EOF
{
  "name": "Local LlamaCPP",
  "type": "llama_cpp",
  "url": "http://127.0.0.1:${ROUTER_PORT}",
  "model": "${MODEL_ID}"
}
EOF
    info "Wrote provider hint: ${PROVIDER_FILE}"
  fi
else
  warn "Server did not respond on ${ROUTER_PORT} - check ${ROUTER_DIR}/llama-server.log"
  tail -n 50 "${ROUTER_DIR}/llama-server.log" || true
fi

info "Done. Manifest: ${MANIFEST_FILE}"
