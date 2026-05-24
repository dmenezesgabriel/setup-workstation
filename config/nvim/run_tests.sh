#!/usr/bin/env bash
set -e
set -u
set -o pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TEST_DIR="$SCRIPT_DIR/tests"
BUILD_SCRIPT="$SCRIPT_DIR/build_images.sh"
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

mapfile -t TEST_FILES < <(find "$TEST_DIR" -maxdepth 1 -type f -name '*.lua' | sort)
if [ ${#TEST_FILES[@]} -eq 0 ]; then
  echo "ERROR: no Lua test files found in $TEST_DIR" >&2
  exit 1
fi

if [ ! -x "$BUILD_SCRIPT" ]; then
  echo "ERROR: build script not found or not executable: $BUILD_SCRIPT" >&2
  exit 1
fi

if ! "$BUILD_SCRIPT"; then
  echo "ERROR: local Neovim image build failed" >&2
  exit 1
fi

cleanup() {
  for file in "${TMP_FILES[@]:-}"; do
    [ -n "$file" ] && [ -e "$file" ] && rm -f "$file"
  done
}
trap cleanup EXIT

TMP_FILES=()
declare -A RESULTS
passed=0
failed=0

for version in "${VERSIONS[@]}"; do
  for test_file in "${TEST_FILES[@]}"; do
    test_name=$(basename "$test_file" .lua)
    tmp_output=$(mktemp)
    TMP_FILES+=("$tmp_output")

    image_tag="$IMAGE_PREFIX:$version"

    if docker run --rm \
      -v "$SCRIPT_DIR:/config/nvim:ro" \
      -w /config/nvim \
      "$image_tag" \
      nvim --headless -u NONE -c "luafile tests/$test_name.lua" -c "qa!" \
      >"$tmp_output" 2>&1; then
      RESULTS["$version/$test_name"]="PASS"
      passed=$((passed + 1))
    else
      RESULTS["$version/$test_name"]="FAIL"
      failed=$((failed + 1))
      echo "=== FAIL $version/$test_name (image: $image_tag) ==="
      cat "$tmp_output"
      echo "=== END FAIL $version/$test_name (image: $image_tag) ==="
    fi
  done
 done

for version in "${VERSIONS[@]}"; do
  for test_file in "${TEST_FILES[@]}"; do
    test_name=$(basename "$test_file" .lua)
    printf '%-4s  %s/%s\n' "${RESULTS["$version/$test_name"]}" "$version" "$test_name"
  done
done

echo "Total: $passed passed, $failed failed"
exit $((failed > 0))
