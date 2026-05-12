#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}" && pwd)"

# Straightforward, single-command bootstrap for OpenWebUI + llama.cpp (router mode).
# Behavior:
#  - Builds llama.cpp server if missing (calls scripts/12-llamacpp.sh)
#  - Runs the idempotent installer (scripts/14-openwebui-llamacpp-auto.sh)
#  - Auto-tunes hardware config (scripts/15-auto-tune-llamacpp.sh)
#  - Starts the supervised server (owui-start)
#  - Does NOT download large models by default. To enable model download, set
#      DOWNLOAD_LFM2_5=1 HF_TOKEN=your_token
#  Usage (from repo root):
#    bash scripts/00-bootstrap-openwebui-llamacpp.sh
#    DOWNLOAD_LFM2_5=1 HF_TOKEN=... bash scripts/00-bootstrap-openwebui-llamacpp.sh

# Configurable via env:
DOWNLOAD_LFM2_5="${DOWNLOAD_LFM2_5:-0}"
HF_TOKEN="${HF_TOKEN:-}"

info() { printf "\033[0;32m✓\033[0m %s\n" "$*"; }
warn() { printf "\033[0;33m⚠\033[0m %s\n" "$*"; }
fail() { printf "\033[0;31m✖\033[0m %s\n" "$*"; exit 1; }

# Ensure we run from the repo (best effort)
if [ ! -f "${REPO_ROOT}/scripts/12-llamacpp.sh" ]; then
  warn "scripts/12-llamacpp.sh not found in repo; continuing but build may fail"
fi

info "Bootstrap started"
info "DOWNLOAD_LFM2_5=${DOWNLOAD_LFM2_5}"

# Step 1: Build / ensure llama.cpp server binary
if [ -x "${HOME}/src/llama.cpp/build/bin/llama-server" ]; then
  info "llama-server binary already exists: ${HOME}/src/llama.cpp/build/bin/llama-server"
else
  if [ -f "${REPO_ROOT}/scripts/12-llamacpp.sh" ]; then
    info "Building llama.cpp (this may take a while)"
    bash "${REPO_ROOT}/scripts/12-llamacpp.sh"
  else
    warn "No build script available; trying to continue (but server binary may be missing)"
  fi
fi

# Step 2: Run idempotent installer which writes launcher, helper, manifest
info "Running installer (creating launcher, presets, manifest)"
# Pass through DOWNLOAD_LFM2_5 and HF_TOKEN env vars
DOWNLOAD_LFM2_5=${DOWNLOAD_LFM2_5} HF_TOKEN="${HF_TOKEN}" bash "${REPO_ROOT}/scripts/14-openwebui-llamacpp-auto.sh"

# Step 3: Auto-tune hardware config
info "Auto-tuning hardware settings"
bash "${REPO_ROOT}/scripts/15-auto-tune-llamacpp.sh"

# Step 4: Start supervised server
info "Starting supervised server (owui-start)"
# ensure start helper exists
if [ -x "${HOME}/.local/bin/start-llama-openwebui.sh" ]; then
  "${HOME}/.local/bin/start-llama-openwebui.sh" start || warn "start helper failed"
else
  warn "start helper not found; you can start the server manually: ~/.local/openwebui-llamacpp/run-llama-server.sh"
fi

# Step 5: Quick health check
sleep 2
if curl -sS --max-time 5 http://127.0.0.1:8080/v1/models >/dev/null 2>&1; then
  info "Server appears to be responding on http://127.0.0.1:8080"
  info "Use: owui-start / owui-stop / owui-status to manage the server"
else
  warn "Server did not respond on http://127.0.0.1:8080; check logs: ~/.local/openwebui-llamacpp/llama-server.log"
fi

info "Bootstrap finished."

# Print simple next steps
echo
echo "Quick commands (aliases are added to ~/.zshrc):"
echo "  owui-start    # start the supervised server"
echo "  owui-stop     # stop the supervised server"
echo "  owui-status   # check status"
echo "  scripts/17-estimate-memory.py   # estimate memory for models"
echo
exit 0
