#!/usr/bin/env bash
set -e
set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
IMAGE_PREFIX="local/neovim-test"
VERSIONS=(v0.8.3 v0.9.5 v0.10.4 stable)

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker is required but was not found on PATH" >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker daemon is not running or is not reachable" >&2
  exit 1
fi

resolve_stable_version() {
  if [ -n "${STABLE_NVIM_VERSION:-}" ]; then
    printf '%s\n' "$STABLE_NVIM_VERSION"
    return 0
  fi

  python3 - <<'PY'
import json, urllib.request
with urllib.request.urlopen('https://api.github.com/repos/neovim/neovim/releases/latest') as response:
    print(json.load(response)['tag_name'])
PY
}

resolve_asset_url() {
  local version=$1
  python3 - "$version" <<'PY'
import json
import platform
import sys
import urllib.request

version = sys.argv[1]
machine = platform.machine().lower()
asset_candidates = {
    'x86_64': ['nvim-linux-x86_64.tar.gz', 'nvim-linux64.tar.gz'],
    'amd64': ['nvim-linux-x86_64.tar.gz', 'nvim-linux64.tar.gz'],
    'aarch64': ['nvim-linux-arm64.tar.gz'],
    'arm64': ['nvim-linux-arm64.tar.gz'],
}

if machine not in asset_candidates:
    raise SystemExit(f'Unsupported host architecture for Neovim test images: {machine}')

with urllib.request.urlopen(f'https://api.github.com/repos/neovim/neovim/releases/tags/{version}') as response:
    release = json.load(response)

assets = {asset['name']: asset['browser_download_url'] for asset in release['assets']}
for asset_name in asset_candidates[machine]:
    if asset_name in assets:
        print(assets[asset_name])
        break
else:
    candidates = ', '.join(asset_candidates[machine])
    raise SystemExit(f'No matching Neovim asset for {version} on {machine}. Tried: {candidates}')
PY
}

for version in "${VERSIONS[@]}"; do
  image_tag="$IMAGE_PREFIX:$version"
  build_version="$version"
  if [ "$version" = "stable" ]; then
    build_version="$(resolve_stable_version)"
    echo "=== BUILD $image_tag (resolved ${build_version}) ==="
  else
    echo "=== BUILD $image_tag (${build_version}) ==="
  fi

  asset_url="$(resolve_asset_url "$build_version")"

  docker build \
    -f "$SCRIPT_DIR/Dockerfile.nvim-test" \
    --build-arg NVIM_VERSION="$build_version" \
    --build-arg NVIM_TARBALL_URL="$asset_url" \
    -t "$image_tag" \
    "$SCRIPT_DIR"

done
