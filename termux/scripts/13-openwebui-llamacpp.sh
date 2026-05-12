#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_SH="${RUN_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/lib.sh"
# shellcheck disable=SC1091
source "${LIB_SH}"

# Replace the custom Python FastAPI "router.py" with integration to the
# native llama.cpp HTTP server in router mode. The native server handles
# on-demand model loading/unloading and exposes OpenAI-compatible endpoints
# which OpenWebUI can connect to directly.

ROUTER_DIR="${ROUTER_DIR:-${HOME}/.local/openwebui-llamacpp}"
MODELS_DIR="${MODELS_DIR:-${ROUTER_DIR}/models}"
ROUTER_PORT="${ROUTER_PORT:-8080}"
HF_TOKEN="${HF_TOKEN:-}"
LLAMA_DIR="${LLAMA_DIR:-${HOME}/src/llama.cpp}"

info "Config: ROUTER_DIR=${ROUTER_DIR}, MODELS_DIR=${MODELS_DIR}, ROUTER_PORT=${ROUTER_PORT}, LLAMA_DIR=${LLAMA_DIR}"

mkdir -p "${ROUTER_DIR}"
mkdir -p "${MODELS_DIR}"

# Try to find a built llama.cpp 'server' binary in the expected build output
find_server_bin() {
    local d="${LLAMA_DIR}/build/bin"
    if [ -d "${d}" ]; then
        # prefer obvious server names
        for n in server "llama-server" "llama.cpp-server" "llama-server"; do
            if [ -x "${d}/${n}" ]; then
                printf "%s\n" "${d}/${n}"
                return 0
            fi
        done
        # fallback: any executable with 'server' in the name
        local f
        f=$(find "${d}" -maxdepth 1 -type f -executable -iname "*server*" | head -n1 || true)
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

# If server binary not present, try to build a server target (with minimal parallelism)
if [ -z "${SERVER_BIN}" ]; then
    warn "llama.cpp server binary not found in ${LLAMA_DIR}; attempting to build the server target (may need additional RAM/CPU)"
    if [ ! -d "${LLAMA_DIR}" ]; then
        fail_step "llama.cpp repo not found at ${LLAMA_DIR}; please run scripts/12-llamacpp.sh to clone/build llama.cpp"
        exit 1
    fi

    cd "${LLAMA_DIR}"
    # Clean previous build to force server target configuration
    rm -rf build || true

    # Configure CMake to include the server target; use Ninja and limit to 1 job to be conservative
    info "Configuring cmake to build server (this may take a while)"
    cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_TOOLS=ON -DGGML_OPENMP=OFF -DBUILD_SHARED_LIBS=OFF || {
        fail_step "cmake configure for server failed"
        exit 1
    }

    info "Building server target (jobs=1)"
    cmake --build build --target server -- -j 1 || cmake --build build --target llama-server -- -j 1 || cmake --build build -- -j 1

    SERVER_BIN=$(find_server_bin || true)
fi

if [ -z "${SERVER_BIN}" ]; then
    fail_step "Could not find or build a llama.cpp server binary in ${LLAMA_DIR}/build/bin. Aborting."
    exit 1
fi

info "Found llama.cpp server binary: ${SERVER_BIN}"

# Inspect the server help to determine available flags
HELP_OUT="$(${SERVER_BIN} --help 2>&1 || true)"

action_has_flag() {
    local flag="$1"
    printf "%s" "${HELP_OUT}" | grep -q -- "${flag}"
}

# Determine router flag availability and models-dir flag
if action_has_flag --router; then
    ROUTER_FLAG="--router"
else
    ROUTER_FLAG=""  # older/newer builds may not require an explicit --router flag
fi

# models-dir flag name
if action_has_flag --models-dir; then
    MODELSDIR_FLAG="--models-dir"
elif action_has_flag --model-dir; then
    MODELSDIR_FLAG="--model-dir"
else
    MODELSDIR_FLAG="--models-dir" # default to --models-dir
fi

# Determine how to pass host/port
if action_has_flag --http-port; then
    HOST_FLAG="--http-host"
    PORT_FLAG="--http-port"
elif action_has_flag --http; then
    # server supports --http <host:port>
    HOST_FLAG="--http"
    PORT_FLAG=""  # will be passed as single arg
elif action_has_flag --host && action_has_flag --port; then
    HOST_FLAG="--host"
    PORT_FLAG="--port"
else
    # fallback to --http if present, else default to --host/--port
    if action_has_flag --http; then
        HOST_FLAG="--http"
        PORT_FLAG=""
    else
        HOST_FLAG="--host"
        PORT_FLAG="--port"
    fi
fi

# Create a launcher script
LAUNCH_SH="${ROUTER_DIR}/run-llama-server.sh"
cat > "${LAUNCH_SH}" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
MODELS_DIR="${MODELS_DIR}"
ROUTER_PORT="${ROUTER_PORT}"
SERVER_BIN="${SERVER_BIN}"
HF_TOKEN="${HF_TOKEN}"

# Start llama.cpp server in router mode, with the models directory
EOF

# Build the actual invocation depending on flags
if [ -n "${HOST_FLAG}" ] && [ -n "${PORT_FLAG}" ]; then
    cat >> "${LAUNCH_SH}" <<EOF
exec "${SERVER_BIN}" ${ROUTER_FLAG} ${HOST_FLAG} 127.0.0.1 ${PORT_FLAG} ${ROUTER_PORT} ${MODELSDIR_FLAG} "${MODELS_DIR}" --hf-token "${HF_TOKEN}"
EOF
elif [ "${HOST_FLAG}" = "--http" ]; then
    cat >> "${LAUNCH_SH}" <<EOF
exec "${SERVER_BIN}" ${ROUTER_FLAG} --http 127.0.0.1:${ROUTER_PORT} ${MODELSDIR_FLAG} "${MODELS_DIR}" --hf-token "${HF_TOKEN}"
EOF
else
    # No explicit host/port flags detected; just run router with model-dir and hope server defaults to reasonable HTTP interface
    cat >> "${LAUNCH_SH}" <<EOF
exec "${SERVER_BIN}" ${ROUTER_FLAG} ${MODELSDIR_FLAG} "${MODELS_DIR}" --hf-token "${HF_TOKEN}" --port ${ROUTER_PORT}
EOF
fi

chmod +x "${LAUNCH_SH}"

info "Created server launcher: ${LAUNCH_SH}"

echo "To start the llama.cpp server in router mode, run:"
echo "  ${LAUNCH_SH}"
echo "Then point OpenWebUI to http://127.0.0.1:${ROUTER_PORT} as an OpenAI-compatible provider."

# Try to start the server in background for a quick sanity check
LOG="${ROUTER_DIR}/llama-server.log"
info "Starting server (background) for sanity check; logs -> ${LOG}"
nohup "${LAUNCH_SH}" >"${LOG}" 2>&1 &
# Give it a few seconds to start
sleep 3

# Wait for an HTTP response on the port
ready=0
for i in {1..10}; do
    # Try a few endpoints the server commonly exposes
    if curl -sS "http://127.0.0.1:${ROUTER_PORT}/v1/models" >/dev/null 2>&1 || curl -sS "http://127.0.0.1:${ROUTER_PORT}/models" >/dev/null 2>&1 || curl -sS "http://127.0.0.1:${ROUTER_PORT}/v1" >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 1
done

if [ "${ready}" -eq 1 ]; then
    info "llama.cpp server appears to be responding on port ${ROUTER_PORT}"
    echo "Point OpenWebUI to http://127.0.0.1:${ROUTER_PORT}"

    # Try to detect a default model and emit an OpenWebUI provider file for reproducibility
    MODELS_JSON="$(curl -sS "http://127.0.0.1:${ROUTER_PORT}/v1/models" || true)"
    if [ -n "${MODELS_JSON}" ]; then
        # attempt to extract a model id using jq if available, else simple parse
        if command -v jq >/dev/null 2>&1; then
            MODEL_ID=$(printf "%s" "${MODELS_JSON}" | jq -r '.data[0].id // .data[0].name // .data[0].model // empty') || true
        else
            MODEL_ID=$(printf "%s" "${MODELS_JSON}" | sed -n 's/.*"id":\s*"\([^"]\+\)".*/\1/p' | head -n1 || true)
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
            info "Wrote OpenWebUI provider hint: ${PROVIDER_FILE} (contains detected model id)"
        else
            info "No model id detected from server probe; please place a GGUF model in ${MODELS_DIR} or add via server API"
        fi
    fi

else
    warn "Server did not respond to probe on port ${ROUTER_PORT} within the timeout. Check logs: ${LOG}"
    tail -n 50 "${LOG}" || true
fi

# Ensure an idempotent zsh alias exists for starting the server (alias only)
ZSHRC="$HOME/.zshrc"
ALIAS_LINE="alias owui=\"${HOME}/.local/bin/start-llama-openwebui.sh\""
if [ -f "${ZSHRC}" ]; then
    if ! grep -Fq "${ALIAS_LINE}" "${ZSHRC}"; then
        printf "\n# OpenWebUI helper alias (created by scripts/13-openwebui-llamacpp.sh)\n%s\n" "${ALIAS_LINE}" >> "${ZSHRC}"
        info "Added alias to ${ZSHRC}: owui"
    else
        info "Alias already present in ${ZSHRC}"
    fi
else
    printf "%s\n" "${ALIAS_LINE}" > "${ZSHRC}"
    info "Created ${ZSHRC} with owui alias"
fi

info "Script finished."

