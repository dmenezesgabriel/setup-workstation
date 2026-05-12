#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_SH="${RUN_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/lib.sh"
# shellcheck disable=SC1091
source "${LIB_SH}"

# Simple installer / launcher for an OpenAI-compatible "llama.cpp router" using
# llama-cpp-python and a small FastAPI app. The router lazily loads GGUF models
# downloaded from Hugging Face and unloads them when idle to suit low-RAM
# devices. Everything is configurable via environment variables and a models
# manifest.

# Configuration (can be set in the environment before running this script):
#  ROUTER_VENV - path where the python venv will be created (default: $HOME/.local/openwebui-llamacpp-venv)
#  ROUTER_DIR  - directory to store router code and models (default: $HOME/.local/openwebui-llamacpp)
#  MODELS_DIR  - where GGUF model files will be stored (default: $ROUTER_DIR/models)
#  ROUTER_PORT - HTTP port for the router (default: 8080)
#  IDLE_UNLOAD_SECONDS - seconds of idle time before unloading a model (default: 120)
#  MAX_LOADED_MODELS - maximum number of models to keep loaded concurrently (default: 1)
#  HF_TOKEN - Hugging Face token (optional, needed for private models)

ROUTER_VENV="${ROUTER_VENV:-${HOME}/.local/openwebui-llamacpp-venv}"
ROUTER_DIR="${ROUTER_DIR:-${HOME}/.local/openwebui-llamacpp}"
MODELS_DIR="${MODELS_DIR:-${ROUTER_DIR}/models}"
ROUTER_PORT="${ROUTER_PORT:-8080}"
IDLE_UNLOAD_SECONDS="${IDLE_UNLOAD_SECONDS:-120}"
MAX_LOADED_MODELS="${MAX_LOADED_MODELS:-1}"
HF_TOKEN="${HF_TOKEN:-}"

PYTHON_BIN="${ROUTER_VENV}/bin/python"
PIP_BIN="${ROUTER_VENV}/bin/pip"
UVICORN_BIN="${ROUTER_VENV}/bin/uvicorn"

info "Setting up OpenWebUI llama-cpp router"
info "Router dir: ${ROUTER_DIR}"
info "Models dir: ${MODELS_DIR}"

mkdir -p "${ROUTER_DIR}"
mkdir -p "${MODELS_DIR}"

# Create venv
if [ ! -x "${PYTHON_BIN}" ]; then
    info "Creating python venv at ${ROUTER_VENV}"
    python3 -m venv "${ROUTER_VENV}"
fi

info "Upgrading pip and installing Python dependencies"
"${PIP_BIN}" install --upgrade pip
# Pin simple, tested versions for reproducibility. Adjust as needed.
"${PIP_BIN}" install fastapi==0.100.0 uvicorn==0.22.0 huggingface-hub==0.16.4 llama-cpp-python==0.1.51

# Write the router app
ROUTER_PY="${ROUTER_DIR}/router.py"
cat > "${ROUTER_PY}" <<'PY'
#!/usr/bin/env python3
"""
A lightweight OpenAI-compatible router that uses llama-cpp-python to load GGUF
models on-demand. It exposes a minimal OpenAI Chat Completions endpoint so you
can point OpenWebUI (or any OpenAI-compatible client) at it.

Features:
- Download models from Hugging Face via the /models/add endpoint.
- Lazily load models into memory when requested.
- Enforce a max number of concurrently loaded models and unload least recently
  used models when needed.
- Unload idle models after a configurable timeout.

Simple usage:
  POST /models/add {"repo_id": "LiquidAI/LFM2.5-350M-GGUF"}
  POST /v1/chat/completions (OpenAI-compatible payload)

This is intentionally small and dependency-light to work on constrained devices.
"""
import os
import time
import threading
import json
from typing import Dict, Any
from collections import OrderedDict
from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
from huggingface_hub import hf_hub_download, HfApi

# Optional: provide HF token via environment
HF_TOKEN = os.environ.get("HF_TOKEN")
MODELS_DIR = os.environ.get("MODELS_DIR", os.path.expanduser("~/.local/openwebui-llamacpp/models"))
IDLE_UNLOAD_SECONDS = int(os.environ.get("IDLE_UNLOAD_SECONDS", "120"))
MAX_LOADED_MODELS = int(os.environ.get("MAX_LOADED_MODELS", "1"))

os.makedirs(MODELS_DIR, exist_ok=True)

app = FastAPI()
api = HfApi()

# Model manifest keeps metadata about downloaded models.
MANIFEST_PATH = os.path.join(MODELS_DIR, "models.json")
if os.path.exists(MANIFEST_PATH):
    with open(MANIFEST_PATH, "r", encoding="utf-8") as f:
        MANIFEST = json.load(f)
else:
    MANIFEST = {}

# In-memory loaded model objects (LRU)
# key -> {"llm": Llama instance, "last_used": timestamp, "timer": Timer}
LOADED: "OrderedDict[str, Dict[str, Any]]" = OrderedDict()
lock = threading.Lock()

# Try to import llama-cpp-python lazily; if unavailable we will error on usage.
try:
    from llama_cpp import Llama
except Exception as e:
    Llama = None

class AddModelReq(BaseModel):
    repo_id: str
    filename: str = "model.gguf"
    revision: str | None = None

class OpenAIMessage(BaseModel):
    role: str
    content: str

class OpenAIChatReq(BaseModel):
    model: str
    messages: list[OpenAIMessage]
    max_tokens: int | None = 128


def save_manifest():
    with open(MANIFEST_PATH, "w", encoding="utf-8") as f:
        json.dump(MANIFEST, f, indent=2)


def ensure_not_native_missing():
    if Llama is None:
        raise RuntimeError("llama-cpp-python is not available in the environment; ensure the venv has it installed.")


def download_model(repo_id: str, filename: str = "model.gguf", revision: str | None = None) -> str:
    """Download a file from a HF repo into MODELS_DIR and record it in manifest.
    Returns the local path.
    """
    token = os.environ.get("HF_TOKEN")
    try:
        local_path = hf_hub_download(repo_id=repo_id, filename=filename, revision=revision, cache_dir=MODELS_DIR, token=token)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to download model: {e}")
    # hf_hub_download may return a path inside cache_dir; we copy it to MODELS_DIR root for clarity
    base_name = os.path.basename(local_path)
    dest = os.path.join(MODELS_DIR, base_name)
    if os.path.abspath(local_path) != os.path.abspath(dest):
        try:
            import shutil
            shutil.copy2(local_path, dest)
        except Exception:
            # fallback: keep original path
            dest = local_path
    MANIFEST[repo_id + "/" + filename] = {"repo_id": repo_id, "filename": filename, "local_path": dest, "revision": revision}
    save_manifest()
    return dest


def load_model(model_key: str):
    """Load a manifest model into memory (Llama instance). Model_key is repo_id/filename or a manifest key.
    Uses LRU eviction to ensure we don't keep more than MAX_LOADED_MODELS loaded.
    """
    ensure_not_native_missing()
    with lock:
        # normalize key
        key = model_key
        if key not in MANIFEST:
            raise HTTPException(status_code=404, detail="Model not found in manifest; add it via /models/add")
        meta = MANIFEST[key]
        path = meta.get("local_path")

        # If already loaded, update recency and return
        if key in LOADED:
            LOADED.move_to_end(key)
            LOADED[key]["last_used"] = time.time()
            # cancel any pending unload timer and set a fresh one
            timer = LOADED[key].get("timer")
            if timer:
                timer.cancel()
            LOADED[key]["timer"] = threading.Timer(IDLE_UNLOAD_SECONDS, lambda: unload_model(key))
            LOADED[key]["timer"].daemon = True
            LOADED[key]["timer"].start()
            return LOADED[key]["llm"]

        # Evict if necessary
        while len(LOADED) >= MAX_LOADED_MODELS and len(LOADED) > 0:
            # pop the oldest
            old_key, _ = LOADED.popitem(last=False)
            try:
                unload_model(old_key)
            except Exception:
                pass

        # Create the Llama instance
        try:
            llm = Llama(model_path=path)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Failed to load model: {e}")

        LOADED[key] = {"llm": llm, "last_used": time.time(), "timer": None}
        LOADED.move_to_end(key)
        LOADED[key]["timer"] = threading.Timer(IDLE_UNLOAD_SECONDS, lambda: unload_model(key))
        LOADED[key]["timer"].daemon = True
        LOADED[key]["timer"].start()
        return llm


def unload_model(key: str):
    """Unload a model from memory and free resources."""
    with lock:
        entry = LOADED.pop(key, None)
    if not entry:
        return
    try:
        timer = entry.get("timer")
        if timer:
            timer.cancel()
    except Exception:
        pass
    try:
        # llama-cpp-python exposes a close method
        entry["llm"].close()
    except Exception:
        pass


@app.post("/models/add")
def add_model(req: AddModelReq):
    repo = req.repo_id
    fn = req.filename
    rev = req.revision
    path = download_model(repo, fn, rev)
    return {"status": "ok", "local_path": path, "manifest_key": repo + "/" + fn}


@app.get("/models/list")
def list_models():
    return {"models": MANIFEST}


@app.post("/v1/chat/completions")
def chat_completions(req: OpenAIChatReq):
    # Use last message content as prompt (simple mapping)
    if not req.messages:
        raise HTTPException(status_code=400, detail="messages is required")
    prompt = req.messages[-1].content
    model_key = req.model
    llm = load_model(model_key)
    try:
        # llama-cpp-python create completion
        resp = llm.create_completion(prompt=prompt, max_tokens=req.max_tokens or 128)
        # response contains choices which include text
        text = resp.get("choices", [{}])[0].get("text", "")
        return {"id": "llamacpp-router-1", "object": "text_completion", "choices": [{"text": text}], "model": model_key}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Generation failed: {e}")


@app.post("/v1/models/reload")
def reload_models():
    # Useful for debugging: unload everything
    keys = list(LOADED.keys())
    for k in keys:
        unload_model(k)
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("ROUTER_PORT", "8080"))
    uvicorn.run("router:app", host="127.0.0.1", port=port, log_level="info")
PY

chmod +x "${ROUTER_PY}"

# Create a small launcher script
LAUNCH_SH="${ROUTER_DIR}/run-router.sh"
cat > "${LAUNCH_SH}" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
export MODELS_DIR="${MODELS_DIR}"
export HF_TOKEN="${HF_TOKEN}"
export IDLE_UNLOAD_SECONDS="${IDLE_UNLOAD_SECONDS}"
export MAX_LOADED_MODELS="${MAX_LOADED_MODELS}"
export ROUTER_PORT="${ROUTER_PORT}"
"${UVICORN_BIN}" router:app --host 127.0.0.1 --port ${ROUTER_PORT} --reload
EOF
chmod +x "${LAUNCH_SH}"

info "Downloading test model LiquidAI/LFM2.5-350M-GGUF into models dir (this may take a while)"
# Use the installed python to call a small helper to download reproducibly
"${PYTHON_BIN}" - <<PYCODE
from huggingface_hub import hf_hub_download
import os, json
models_dir = os.environ.get('MODELS_DIR', '${MODELS_DIR}')
repo='LiquidAI/LFM2.5-350M-GGUF'
fn='LFM2.5-350M.gguf'
# Some repos use different filenames; attempt common ones
candidates = ['model.gguf', 'LFM2.5-350M.gguf', 'LFM2.5-350M-GGUF.gguf']
for f in candidates:
    try:
        p = hf_hub_download(repo_id=repo, filename=f, cache_dir=models_dir, token=os.environ.get('HF_TOKEN'))
        # copy into models_dir root
        import shutil
        dest = os.path.join(models_dir, os.path.basename(p))
        if os.path.abspath(p) != os.path.abspath(dest):
            shutil.copy2(p, dest)
        manifest_path = os.path.join(models_dir, 'models.json')
        key = repo + '/' + f
        manifest = {}
        if os.path.exists(manifest_path):
            manifest = json.load(open(manifest_path,'r'))
        manifest[key] = {'repo_id': repo, 'filename': f, 'local_path': dest}
        json.dump(manifest, open(manifest_path, 'w'), indent=2)
        print('downloaded', dest)
        break
    except Exception as e:
        # try next candidate
        last = e
else:
    print('WARNING: did not find expected file in repo; please run the /models/add endpoint with exact filename')
PYCODE

info "Install complete. To run the router:"
echo "  ${LAUNCH_SH}"
echo "Then point OpenWebUI to http://127.0.0.1:${ROUTER_PORT} as an OpenAI-compatible provider."

echo "Example: add the test model using the router's endpoint (if not auto-downloaded):"
echo "  curl -X POST http://127.0.0.1:${ROUTER_PORT}/models/add -H 'Content-Type: application/json' -d '{\"repo_id\": \"LiquidAI/LFM2.5-350M-GGUF\", \"filename\": \"model.gguf\"}'"

echo "Example OpenAI-compatible request to generate:"
echo "  curl -s -X POST http://127.0.0.1:${ROUTER_PORT}/v1/chat/completions -H 'Content-Type: application/json' -d '{\"model\": \"LiquidAI/LFM2.5-350M-GGUF/model.gguf\", \"messages\": [{\"role\": \"user\", \"content\": \"Say hello\"}] }'"

info "Script finished."

