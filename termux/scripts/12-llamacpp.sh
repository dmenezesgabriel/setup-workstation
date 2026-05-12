#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_SH="${RUN_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/lib.sh"
# shellcheck disable=SC1091
# shellcheck source=../lib.sh
source "${LIB_SH}"

main() {
    echo -e "${PURPLE}Building llama.cpp for this Android device (Snapdragon 865)...${NC}"
    echo ""

    install_pkg_list "llama-build-deps" git build-essential clang make cmake ninja pkg-config python

    local REPO="https://github.com/ggerganov/llama.cpp"
    local DEST_DIR="${HOME}/src/llama.cpp"

    mkdir -p "${HOME}/src"

    if [ -d "${DEST_DIR}/.git" ]; then
        info "Updating existing repo at ${DEST_DIR}"
        if ! run_with_spinner_arr "git pull" -- git -C "${DEST_DIR}" pull --ff-only; then
            warn "git pull failed; trying to fetch and reset"
            run_with_spinner_arr "git fetch" -- git -C "${DEST_DIR}" fetch --depth=1 || true
        fi
    else
        info "Cloning llama.cpp into ${DEST_DIR}"
        if ! run_with_spinner_arr "git clone" -- git clone --depth 1 "${REPO}" "${DEST_DIR}"; then
            fail_step "git clone failed"
            return 1
        fi
    fi

    # Detect architecture and CPU features and prepare tuned CFLAGS for Snapdragon 865
    local ARCH CFLAGS CXXFLAGS CMAKE_GENERATOR JOBS USE_CCACHE REPRO_COMMIT
    ARCH="$(uname -m)"

    # Conservative, reproducible flags for aarch64 Snapdragon 865 (Cortex-A77 cores)
    CFLAGS="-O3 -fPIC -fomit-frame-pointer -march=armv8.2-a -mtune=cortex-a77"
    CXXFLAGS="${CFLAGS}"

    # Prefer Ninja and limit parallelism for low-RAM devices. Allow override via MAX_JOBS env var.
    CMAKE_GENERATOR="Ninja"
    JOBS="${MAX_JOBS:-2}"

    # Try to use ccache when available to speed repeated builds and reduce IO
    if command -v ccache >/dev/null 2>&1; then
        USE_CCACHE=1
        info "ccache detected -> enabling CMake compiler launcher"
    else
        USE_CCACHE=0
    fi

    # Allow reproducible builds by checking out a specific commit if LLAMA_COMMIT is provided
    if [ -n "${LLAMA_COMMIT:-}" ]; then
        REPRO_COMMIT="${LLAMA_COMMIT}"
        info "Checking out requested commit ${REPRO_COMMIT} for reproducible build"
        run_with_spinner_arr "git checkout" -- git -C "${DEST_DIR}" fetch --depth=1 origin "${REPRO_COMMIT}" || true
        if ! run_with_spinner_arr "git checkout" -- git -C "${DEST_DIR}" checkout --force "${REPRO_COMMIT}"; then
            warn "Could not checkout ${REPRO_COMMIT}; continuing on current branch"
        fi
    fi

    cd "${DEST_DIR}" || return 1

    info "Cleaning previous builds to free disk/RAM"
    run_with_spinner_arr "rm build" -- bash -lc 'rm -rf build build-* || true'

    info "Configuring CMake (generator=${CMAKE_GENERATOR})"

    # Build minimal set to reduce memory: disable tests/examples/server, enable tools (cli)
    local CMAKE_ARGS="-G ${CMAKE_GENERATOR} -DCMAKE_BUILD_TYPE=Release \
        -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_SERVER=OFF \
        -DLLAMA_BUILD_TOOLS=ON -DLLAMA_BUILD_COMMON=ON \
        -DGGML_OPENMP=OFF -DBUILD_SHARED_LIBS=OFF"

    # Add ccache launcher if available
    if [ "${USE_CCACHE}" = "1" ]; then
        CMAKE_ARGS+=" -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache"
    fi

    # Preserve any user-supplied extra args
    if [ -n "${LLAMA_CMAKE_ARGS:-}" ]; then
        CMAKE_ARGS+=" ${LLAMA_CMAKE_ARGS}"
    fi

    # Export flags so CMake picks them up
    export CFLAGS CXXFLAGS

    if ! run_with_spinner_arr "cmake configure" -- cmake -S . -B build ${CMAKE_ARGS}; then
        fail_step "cmake configure failed"
        return 1
    fi

    info "Building a minimal set of targets to save RAM (jobs=${JOBS})"

    # Candidate targets in order of preference. We'll try to build them sequentially until one succeeds.
    local -a TARGETS=(llama-cli llama-completion llama-simple llama-bench)
    local built=0 built_target="" tgt

    for tgt in "${TARGETS[@]}"; do
        info "Attempting to build target: ${tgt} (if present)"
        if run_with_spinner_arr "cmake build ${tgt}" -- cmake --build build --target "${tgt}" -- -j "${JOBS}"; then
            built=1
            built_target="${tgt}"
            break
        else
            warn "Build of ${tgt} failed or target missing; trying next target"
        fi
    done

    if [ "${built}" -ne 1 ]; then
        warn "No preferred targets built successfully; attempting a generic build with limited parallelism (may still OOM)"
        if ! run_with_spinner_arr "cmake build all" -- cmake --build build -- -j 1; then
            fail_step "cmake build failed (no targets succeeded)"
            return 1
        fi
        built_target=""
    fi

    # Determine produced binary path for the built target (fallbacks)
    local BIN=""
    case "${built_target}" in
        llama-cli) BIN="build/bin/llama-cli" ;;
        llama-completion) BIN="build/bin/llama-completion" ;;
        llama-simple) BIN="build/bin/llama-simple" ;;
        llama-bench) BIN="build/bin/llama-bench" ;;
        "") BIN="$(ls -1 build/bin 2>/dev/null | head -n1)" ;;
    esac

    if [ -n "${BIN}" ] && [ -f "${DEST_DIR}/${BIN}" ]; then
        info "Built binary: ${DEST_DIR}/${BIN}"
        # Strip to save space if strip available
        if command -v strip >/dev/null 2>&1; then
            run_with_spinner_arr "strip binary" -- strip -s "${DEST_DIR}/${BIN}" || true
            info "Stripped binary to reduce size"
        fi
        log_file "binary: ${DEST_DIR}/${BIN}"
    else
        warn "Build finished but no expected binaries found in build/bin"
        log_file "binaries: $(ls -1 build/bin 2>/dev/null || true)"
        fail_step "llama build: binary not found"
        return 1
    fi

    # Record reproducible metadata
    printf '%s\n' "commit: $(git -C "${DEST_DIR}" rev-parse --short HEAD 2>/dev/null || echo unknown)" "cmake_args: ${CMAKE_ARGS}" "cflags: ${CFLAGS}" > "${DEST_DIR}/build/BUILD_INFO.txt" || true

    echo ""
    info "llama.cpp build finished (minimal CLI build)"
}

main "$@"
