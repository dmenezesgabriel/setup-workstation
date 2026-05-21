#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_SH="${RUN_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/lib.sh"
# shellcheck disable=SC1090,SC1091
source "${LIB_SH}"

LLAMACPP_HOME="${LLAMACPP_HOME:-${ROUTER_DIR:-${HOME}/.local/llamacpp}}"
ROUTER_DIR="${LLAMACPP_HOME}"
MODELS_DIR="${MODELS_DIR:-${LLAMACPP_HOME}/models}"
ROUTER_PORT="${ROUTER_PORT:-8080}"
HF_TOKEN="${HF_TOKEN:-}"
LLAMA_DIR="${LLAMA_DIR:-${HOME}/src/llama.cpp}"
DOWNLOAD_LFM2_5="${DOWNLOAD_LFM2_5:-1}"
MANIFEST_FILE="${MODELS_DIR}/models.json"
BIN_DIR="${HOME}/.local/bin"
HELPER_BIN="${BIN_DIR}/llamacpp"
CONFIG_FILE="${LLAMACPP_HOME}/config.env"

info "Auto setup: LLAMACPP_HOME=${LLAMACPP_HOME}, MODELS_DIR=${MODELS_DIR}, LLAMA_DIR=${LLAMA_DIR}"
mkdir -p "${LLAMACPP_HOME}" "${MODELS_DIR}" "${BIN_DIR}"

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
    MANIFEST_JSON=$(<"${MANIFEST_FILE}") || MANIFEST_JSON='{}'
  else
    MANIFEST_JSON='{}'
  fi
}

save_manifest() {
  printf '%s\n' "${MANIFEST_JSON}" > "${MANIFEST_FILE}.tmp"
  mv "${MANIFEST_FILE}.tmp" "${MANIFEST_FILE}"
}

find_server_bin() {
  local d="${LLAMA_DIR}/build/bin"
  local n
  [ -d "${d}" ] || return 1
  for n in llama-server server "llama.cpp-server"; do
    if [ -x "${d}/${n}" ]; then
      printf '%s\n' "${d}/${n}"
      return 0
    fi
  done
  find "${d}" -maxdepth 1 -type f -executable \( -iname '*llama*server*' -o -iname 'server*' \) | head -n1 || true
}

find_cli_bin() {
  local d="${LLAMA_DIR}/build/bin"
  local n
  [ -d "${d}" ] || return 1
  for n in llama-cli llama-simple main; do
    if [ -x "${d}/${n}" ]; then
      printf '%s\n' "${d}/${n}"
      return 0
    fi
  done
  find "${d}" -maxdepth 1 -type f -executable \( -iname 'llama-cli*' -o -iname 'llama-simple*' \) | head -n1 || true
}

ensure_binaries() {
  SERVER_BIN="$(find_server_bin || true)"
  CLI_BIN="$(find_cli_bin || true)"

  if [ -n "${SERVER_BIN}" ] && [ -n "${CLI_BIN}" ]; then
    return 0
  fi

  warn "Missing llama.cpp standalone binaries; attempting rebuild"
  if [ ! -d "${LLAMA_DIR}" ]; then
    fail_step "llama.cpp not found at ${LLAMA_DIR}; run scripts/12-llamacpp.sh first"
    exit 1
  fi

  bash "${SCRIPT_DIR}/12-llamacpp.sh"

  SERVER_BIN="$(find_server_bin || true)"
  CLI_BIN="$(find_cli_bin || true)"

  if [ -z "${SERVER_BIN}" ] || [ -z "${CLI_BIN}" ]; then
    fail_step "Could not find/build llama.cpp server and cli binaries in ${LLAMA_DIR}/build/bin"
    exit 1
  fi
}

create_presets_and_manifest() {
  local f base preset lp sha tmp_json
  load_manifest
  for f in "${MODELS_DIR}"/*.gguf; do
    [ -e "${f}" ] || continue
    base="$(basename "${f}" .gguf)"
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
    sha="$(sha256_of "${lp}" || true)"
    if command -v jq >/dev/null 2>&1; then
      tmp_json=$(printf '%s' "${MANIFEST_JSON}" | jq --arg k "${base}" --arg p "${lp}" --arg s "${sha}" '.[$k] = {local_path:$p,sha256:$s,added_at:(now|todate)}') || true
      if [ -n "${tmp_json:-}" ]; then
        MANIFEST_JSON="${tmp_json}"
      fi
    else
      MANIFEST_JSON=$(printf '{"%s":{"local_path":"%s","sha256":"%s","added_at":"%s"}}\n' "${base}" "${lp}" "${sha}" "$(date -u +%FT%TZ)")
    fi
  done
  save_manifest
}

download_lfm2_5() {
  local repo venv dl_out rc target_path
  if [ "${DOWNLOAD_LFM2_5}" != "1" ]; then
    info "Skipping LFM2.5-350M download"
    return 0
  fi
  repo="LiquidAI/LFM2.5-350M-GGUF"
  venv="${LLAMACPP_HOME}/hf-venv"
  if [ ! -x "${venv}/bin/python" ]; then
    info "Creating venv for huggingface_hub at ${venv}"
    python3 -m venv "${venv}"
  fi
  info "Ensuring huggingface-hub is installed inside venv"
  "${venv}/bin/pip" install --upgrade pip >/dev/null 2>&1 || true
  "${venv}/bin/pip" install --no-cache-dir huggingface-hub==0.16.4 >/dev/null 2>&1 || true

  export HF_DOWNLOAD_REPO="${repo}"
  export HF_MODELS_DIR="${MODELS_DIR}"
  export HF_MANIFEST_FILE="${MANIFEST_FILE}"
  rc=0
  dl_out=$("${venv}/bin/python" - <<'PY'
import os,sys,json,hashlib,shutil
from huggingface_hub import HfApi, hf_hub_download
repo = os.environ.get('HF_DOWNLOAD_REPO')
token = os.environ.get('HF_TOKEN') or None
models_dir = os.environ.get('HF_MODELS_DIR')
manifest_file = os.environ.get('HF_MANIFEST_FILE')
api = HfApi()
files = api.list_repo_files(repo_id=repo, use_auth_token=token)
cands = [f for f in files if f.lower().endswith('.gguf')]
if not cands:
    print('ERROR:NO_GGUF')
    sys.exit(3)
fn = cands[0]
path = hf_hub_download(repo_id=repo, filename=fn, cache_dir=models_dir, token=token)
dest = os.path.join(models_dir, os.path.basename(path))
if os.path.abspath(path) != os.path.abspath(dest):
    shutil.copy2(path, dest)
h = hashlib.sha256()
with open(dest,'rb') as fh:
    for chunk in iter(lambda: fh.read(8192), b''):
        h.update(chunk)
sha = h.hexdigest()
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
) || rc=$?
  if [ ${rc} -ne 0 ]; then
    warn "huggingface_hub download failed (code=${rc}): ${dl_out}"
    return 1
  fi
  target_path="$(printf '%s' "${dl_out}" | tail -n1)"
  if [ -f "${target_path}" ]; then
    info "Downloaded model to ${target_path}"
    create_presets_and_manifest
    return 0
  fi
  warn "Download succeeded but expected file not found: ${target_path}"
  return 1
}

write_helper() {
  cat > "${HELPER_BIN}" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

LLAMACPP_HOME="${LLAMACPP_HOME}"
MODELS_DIR="${MODELS_DIR}"
ROUTER_PORT="${ROUTER_PORT}"
SERVER_BIN="${SERVER_BIN}"
CLI_BIN="${CLI_BIN}"
CONFIG_FILE="${CONFIG_FILE}"
HF_TOKEN_DEFAULT="${HF_TOKEN}"
ROUTER_FLAG="${ROUTER_FLAG}"
ROUTER_PID_FILE="${LLAMACPP_HOME}/router.pid"
SERVER_PID_FILE="${LLAMACPP_HOME}/server.pid"
ROUTER_LOG="${LLAMACPP_HOME}/router.log"
SERVER_LOG="${LLAMACPP_HOME}/server.log"

[ -f "\${CONFIG_FILE}" ] && source "\${CONFIG_FILE}"
HF_TOKEN="\${HF_TOKEN:-${HF_TOKEN}}"

find_first_model() {
  local requested="\${1:-}"
  local candidate
  if [ -n "\${requested}" ] && [ -f "\${requested}" ]; then
    printf '%s\n' "\${requested}"
    return 0
  fi
  if [ -n "\${requested}" ]; then
    for candidate in "\${MODELS_DIR}/\${requested}" "\${MODELS_DIR}/\${requested}.gguf"; do
      if [ -f "\${candidate}" ]; then
        printf '%s\n' "\${candidate}"
        return 0
      fi
    done
  fi
  find "\${MODELS_DIR}" -maxdepth 1 -type f -name '*.gguf' | sort | head -n1 || true
}

append_extra_args() {
  local target_name="\$1"
  local extra_args="\${2:-}"
  local -n target_ref="\${target_name}"
  if [ -n "\${extra_args}" ]; then
    # shellcheck disable=SC2206
    local extra=( \${extra_args} )
    target_ref+=("\${extra[@]}")
  fi
}

append_common_args() {
  local target_name="\$1"
  local -n target_ref="\${target_name}"
  if [ -n "\${LLAMA_THREADS:-}" ]; then
    target_ref+=(--threads "\${LLAMA_THREADS}")
  fi
  if [ -n "\${LLAMA_THREADS_BATCH:-}" ]; then
    target_ref+=(--threads-batch "\${LLAMA_THREADS_BATCH}")
  fi
  if [ "\${LLAMA_NO_MMAP:-0}" = "1" ]; then
    target_ref+=(--no-mmap)
  fi
  append_extra_args "\${target_name}" "\${LLAMA_COMMON_ARGS:-}"
}

run_router_foreground() {
  local -a cmd=("\${SERVER_BIN}")
  if [ -n "\${ROUTER_FLAG}" ]; then
    cmd+=("\${ROUTER_FLAG}")
  fi
  cmd+=(--host 127.0.0.1 --port "\${ROUTER_PORT}" --models-dir "\${MODELS_DIR}")
  if [ -n "\${HF_TOKEN}" ]; then
    cmd+=(--hf-token "\${HF_TOKEN}")
  fi
  append_common_args cmd
  append_extra_args cmd "\${LLAMA_ROUTER_ARGS:-}"
  exec "\${cmd[@]}"
}

run_server_foreground() {
  local model
  model="\$(find_first_model "\${1:-}")"
  if [ -z "\${model}" ]; then
    echo "No model found. Put a .gguf in \${MODELS_DIR} or pass a model path." >&2
    exit 1
  fi
  if [ \$# -gt 0 ]; then
    shift
  fi
  local -a cmd=("\${SERVER_BIN}" --host 127.0.0.1 --port "\${ROUTER_PORT}" -m "\${model}")
  append_common_args cmd
  append_extra_args cmd "\${LLAMA_SERVER_ARGS:-}"
  cmd+=("\$@")
  exec "\${cmd[@]}"
}

run_cli_foreground() {
  local model
  model="\$(find_first_model "\${1:-}")"
  if [ -z "\${model}" ]; then
    echo "No model found. Put a .gguf in \${MODELS_DIR} or pass a model path." >&2
    exit 1
  fi
  if [ \$# -gt 0 ]; then
    shift
  fi
  local -a cmd=("\${CLI_BIN}" -m "\${model}")
  append_common_args cmd
  append_extra_args cmd "\${LLAMA_CLI_ARGS:-}"
  if [ \$# -eq 0 ]; then
    cmd+=(-i)
  else
    cmd+=("\$@")
  fi
  exec "\${cmd[@]}"
}

start_bg() {
  local mode="\$1"
  local pid_file="\$2"
  local log_file="\$3"
  shift 3
  if [ -f "\${pid_file}" ] && kill -0 "\$(cat "\${pid_file}")" 2>/dev/null; then
    echo "\${mode} already running"
    return 0
  fi
  nohup "\$@" >"\${log_file}" 2>&1 &
  echo \$! > "\${pid_file}"
  echo "started \${mode} (logs -> \${log_file})"
}

stop_bg() {
  local pid_file="\$1"
  if [ -f "\${pid_file}" ]; then
    kill "\$(cat "\${pid_file}")" 2>/dev/null || true
    rm -f "\${pid_file}"
    echo "stopped"
    return 0
  fi
  echo "not running"
}

status_bg() {
  local pid_file="\$1"
  if [ -f "\${pid_file}" ] && kill -0 "\$(cat "\${pid_file}")" 2>/dev/null; then
    echo "running pid=\$(cat "\${pid_file}")"
    return 0
  fi
  echo "not running"
  return 1
}

case "\${1:-help}" in
  router)
    shift
    run_router_foreground "\$@"
    ;;
  router-start)
    shift
    start_bg router "\${ROUTER_PID_FILE}" "\${ROUTER_LOG}" "\$0" router "\$@"
    ;;
  router-stop)
    stop_bg "\${ROUTER_PID_FILE}"
    ;;
  router-status)
    status_bg "\${ROUTER_PID_FILE}"
    ;;
  server)
    shift
    run_server_foreground "\$@"
    ;;
  server-start)
    shift
    start_bg server "\${SERVER_PID_FILE}" "\${SERVER_LOG}" "\$0" server "\$@"
    ;;
  server-stop)
    stop_bg "\${SERVER_PID_FILE}"
    ;;
  server-status)
    status_bg "\${SERVER_PID_FILE}"
    ;;
  cli)
    shift
    run_cli_foreground "\$@"
    ;;
  stop)
    stop_bg "\${ROUTER_PID_FILE}"
    stop_bg "\${SERVER_PID_FILE}"
    ;;
  status)
    printf 'router: '
    status_bg "\${ROUTER_PID_FILE}" || true
    printf 'server: '
    status_bg "\${SERVER_PID_FILE}" || true
    ;;
  help|--help|-h|*)
    cat <<USAGE
Usage:
  llamacpp router
  llamacpp router-start|router-stop|router-status
  llamacpp server [model]
  llamacpp server-start [model]
  llamacpp server-stop|server-status
  llamacpp cli [model] [extra llama-cli args]
  llamacpp stop|status
USAGE
    ;;
esac
EOF
  chmod +x "${HELPER_BIN}"
}

ensure_aliases() {
  local zshrc alias_block_start alias_block_end tmp_file
  zshrc="${HOME}/.zshrc"
  alias_block_start="# >>> llamacpp aliases >>>"
  alias_block_end="# <<< llamacpp aliases <<<"
  tmp_file="$(mktemp)"

  if [ -f "${zshrc}" ]; then
    awk -v start="${alias_block_start}" -v end="${alias_block_end}" '
      $0 == start {skip=1; next}
      $0 == end {skip=0; next}
      !skip {print}
    ' "${zshrc}" > "${tmp_file}"
  fi

  {
    [ -s "${tmp_file}" ] && cat "${tmp_file}"
    printf '\n%s\n' "${alias_block_start}"
    printf 'alias llama-router="%s router"\n' "${HELPER_BIN}"
    printf 'alias llama-router-start="%s router-start"\n' "${HELPER_BIN}"
    printf 'alias llama-router-stop="%s router-stop"\n' "${HELPER_BIN}"
    printf 'alias llama-router-status="%s router-status"\n' "${HELPER_BIN}"
    printf 'alias llama-server="%s server"\n' "${HELPER_BIN}"
    printf 'alias llama-server-start="%s server-start"\n' "${HELPER_BIN}"
    printf 'alias llama-server-stop="%s server-stop"\n' "${HELPER_BIN}"
    printf 'alias llama-server-status="%s server-status"\n' "${HELPER_BIN}"
    printf 'alias llama-cli="%s cli"\n' "${HELPER_BIN}"
    printf 'alias llamacpp-status="%s status"\n' "${HELPER_BIN}"
    printf 'alias owui-start="%s router-start"\n' "${HELPER_BIN}"
    printf 'alias owui-stop="%s router-stop"\n' "${HELPER_BIN}"
    printf 'alias owui-status="%s router-status"\n' "${HELPER_BIN}"
    printf '%s\n' "${alias_block_end}"
  } > "${zshrc}"

  rm -f "${tmp_file}"
}

write_openwebui_provider_hint() {
  local models_json model_id provider_file
  models_json=$(curl -sS "http://127.0.0.1:${ROUTER_PORT}/v1/models" || true)
  [ -n "${models_json}" ] || return 0

  if command -v jq >/dev/null 2>&1; then
    model_id=$(printf '%s' "${models_json}" | jq -r '.data[0].id // .data[0].name // .data[0].model // empty') || true
  else
    model_id=$(printf '%s' "${models_json}" | sed -n 's/.*"id":\s*"\([^"]\+\)".*/\1/p' | head -n1 || true)
  fi

  [ -n "${model_id}" ] || return 0
  provider_file="${LLAMACPP_HOME}/openwebui-provider.json"
  cat > "${provider_file}" <<EOF
{
  "name": "Local LlamaCPP",
  "type": "llama_cpp",
  "url": "http://127.0.0.1:${ROUTER_PORT}",
  "model": "${model_id}"
}
EOF
  info "Wrote provider hint: ${provider_file}"
}

ensure_binaries
ROUTER_FLAG=""
if "${SERVER_BIN}" --help 2>&1 | grep -q -- '--router'; then
  ROUTER_FLAG="--router"
fi
info "Using server binary: ${SERVER_BIN}"
info "Using cli binary: ${CLI_BIN}"
info "Router flag: ${ROUTER_FLAG:-<implicit>}"

create_presets_and_manifest
download_lfm2_5 || true
LLAMACPP_HOME="${LLAMACPP_HOME}" bash "${SCRIPT_DIR}/15-auto-tune-llamacpp.sh"
write_helper
rm -f "${BIN_DIR}/start-llama-openwebui.sh"
ensure_aliases

"${HELPER_BIN}" router-start || true
sleep 3
if curl -sS "http://127.0.0.1:${ROUTER_PORT}/v1/models" >/dev/null 2>&1; then
  info "Router listening on http://127.0.0.1:${ROUTER_PORT}"
  write_openwebui_provider_hint
else
  warn "Router did not respond on ${ROUTER_PORT} - check ${LLAMACPP_HOME}/router.log"
  tail -n 50 "${LLAMACPP_HOME}/router.log" || true
fi

info "Done. Helper: ${HELPER_BIN}"
info "Aliases added: llama-router, llama-server, llama-cli, owui-start"
info "Manifest: ${MANIFEST_FILE}"
