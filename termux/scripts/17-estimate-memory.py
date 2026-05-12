#!/usr/bin/env python3
"""
Estimate RAM required to load GGUF models for llama.cpp.
Usage: scripts/17-estimate-memory.py [model-path-or-id]
If no argument given, it will estimate every .gguf in the models dir.
"""
import os, sys, json, subprocess
from pathlib import Path

ROUTER_DIR = os.environ.get('ROUTER_DIR', str(Path.home()/'.local/openwebui-llamacpp'))
MODELS_DIR = os.environ.get('MODELS_DIR', str(Path(ROUTER_DIR)/'models'))
API_URL = os.environ.get('API_URL', 'http://127.0.0.1:8080')

def human_mib(x):
    return f"{x:.2f}"

def get_mem_available_mib():
    try:
        with open('/proc/meminfo','r') as f:
            for line in f:
                if line.startswith('MemAvailable:'):
                    kb = int(line.split()[1])
                    return kb/1024
    except Exception:
        return 0.0
    return 0.0


def query_server_models():
    try:
        r = subprocess.run(['curl','-sS', f"{API_URL}/v1/models"], capture_output=True, text=True, timeout=5)
        if r.returncode == 0 and r.stdout:
            return json.loads(r.stdout)
    except Exception:
        pass
    return None


def estimate_from_meta(size_bytes, n_ctx=2048, n_embd=1024, n_layer=24):
    # Conservative multipliers
    model_mem_mib = size_bytes/1024/1024 * 1.2
    # estimate KV cache: n_ctx * n_embd * 2 bytes * (n_layer/12) * 1.1
    kv_bytes = n_ctx * n_embd * 2 * (n_layer/12) * 1.1
    kv_mib = kv_bytes/1024/1024
    overhead_mib = 256
    total = model_mem_mib + kv_mib + overhead_mib
    return model_mem_mib, kv_mib, overhead_mib, total


def estimate_for(arg):
    # arg can be a path to file or model id
    model_file = None
    model_size = 0
    n_ctx = 2048
    n_embd = 1024
    n_layer = 24

    # If arg is file and exists
    p = Path(arg)
    if p.exists() and p.is_file():
        model_file = str(p)
        model_size = p.stat().st_size
    else:
        # look for file in MODELS_DIR by basename
        candidates = [
            Path(MODELS_DIR)/arg,
            Path(MODELS_DIR)/(arg + '.gguf'),
        ]
        for c in candidates:
            if c.exists():
                model_file = str(c)
                model_size = c.stat().st_size
                break

    # If still nothing, try querying server metadata for id
    server_meta = query_server_models()
    if server_meta and 'data' in server_meta:
        # try to find match by id or name
        found = None
        for item in server_meta['data']:
            if item.get('id') == arg or item.get('model') == arg or item.get('name') == arg:
                found = item
                break
        if found:
            meta = found.get('meta', {})
            # meta.size might be number
            size = meta.get('size')
            if not model_size and size:
                model_size = int(size)
            n_ctx = int(meta.get('n_ctx', n_ctx))
            n_embd = int(meta.get('n_embd', n_embd))
            n_layer = int(meta.get('n_layer', n_layer))
            # if preset has model path, use it
            preset = found.get('status',{}).get('args') or found.get('preset')

    # fallback: if still nothing, try to heuristically find a file in models dir
    if not model_file:
        for f in Path(MODELS_DIR).glob('*.gguf'):
            # pick first
            model_file = str(f)
            model_size = f.stat().st_size
            break

    if not model_file or model_size == 0:
        print(f"Could not determine model file or size for '{arg}'")
        return

    model_mem, kv_mem, overhead, total = estimate_from_meta(model_size, n_ctx=n_ctx, n_embd=n_embd, n_layer=n_layer)
    mem_avail = get_mem_available_mib()

    print(f"Estimate for: {arg}")
    print(f"  model_file: {model_file}")
    print(f"  model_size: {model_size/1024/1024:.2f} MiB")
    print(f"  assumed params: n_ctx={n_ctx} n_embd={n_embd} n_layer={n_layer}")
    print(f"  estimated model_mem: {model_mem:.2f} MiB (model_size*1.2)")
    print(f"  estimated kv_mem: {kv_mem:.2f} MiB (approx)")
    print(f"  overhead: {overhead:.2f} MiB")
    print(f"  TOTAL_ESTIMATED: {total:.2f} MiB")
    print(f"  MemAvailable on system: {mem_avail:.0f} MiB")
    if mem_avail > total + 128:
        print("  => Likely safe to load (room >128 MiB)")
    else:
        print("  => WARNING: Not enough available memory to load safely; consider reducing ctx-size or using a smaller model.")


def main():
    args = sys.argv[1:]
    if args:
        for a in args:
            estimate_for(a)
            print()
    else:
        # estimate for all models in models dir
        ggufs = list(Path(MODELS_DIR).glob('*.gguf'))
        if not ggufs:
            print('No .gguf files found in', MODELS_DIR)
            return
        for f in ggufs:
            estimate_for(str(f))
            print()

if __name__ == '__main__':
    main()
