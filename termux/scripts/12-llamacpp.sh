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

    local CFLAGS CXXFLAGS CMAKE_GENERATOR JOBS USE_CCACHE REPRO_COMMIT

    CFLAGS="-O3 -fPIC -fomit-frame-pointer -march=armv8.2-a -mtune=cortex-a77"
    CXXFLAGS="${CFLAGS}"
    CMAKE_GENERATOR="Ninja"
    JOBS="${MAX_JOBS:-2}"

    if command -v ccache >/dev/null 2>&1; then
        USE_CCACHE=1
        info "ccache detected -> enabling CMake compiler launcher"
    else
        USE_CCACHE=0
    fi

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

    local CMAKE_ARGS="-G ${CMAKE_GENERATOR} -DCMAKE_BUILD_TYPE=Release \
        -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF -DLLAMA_BUILD_SERVER=ON \
        -DLLAMA_BUILD_TOOLS=ON -DLLAMA_BUILD_COMMON=ON \
        -DGGML_OPENMP=OFF -DBUILD_SHARED_LIBS=OFF"

    if [ "${USE_CCACHE}" = "1" ]; then
        CMAKE_ARGS+=" -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache"
    fi

    if [ -n "${LLAMA_CMAKE_ARGS:-}" ]; then
        CMAKE_ARGS+=" ${LLAMA_CMAKE_ARGS}"
    fi

    export CFLAGS CXXFLAGS

    # shellcheck disable=SC2086
    if ! run_with_spinner_arr "cmake configure" -- cmake -S . -B build ${CMAKE_ARGS}; then
        fail_step "cmake configure failed"
        return 1
    fi

    info "Building standalone llama.cpp targets (jobs=${JOBS})"

    local -a TARGETS=(llama-cli llama-server server llama-simple llama-bench)
    local -a BUILT_TARGETS=()
    local built_any=0
    local tgt

    for tgt in "${TARGETS[@]}"; do
        info "Attempting to build target: ${tgt} (if present)"
        if run_with_spinner_arr "cmake build ${tgt}" -- cmake --build build --target "${tgt}" -- -j "${JOBS}"; then
            BUILT_TARGETS+=("${tgt}")
            built_any=1
        else
            warn "Build of ${tgt} failed or target missing; continuing"
        fi
    done

    if [ "${built_any}" -ne 1 ]; then
        warn "No preferred targets built successfully; attempting a generic build with limited parallelism (may still OOM)"
        if ! run_with_spinner_arr "cmake build all" -- cmake --build build -- -j 1; then
            fail_step "cmake build failed (no targets succeeded)"
            return 1
        fi
    fi

    local -a FOUND_BINS=()
    local candidate
    for candidate in \
        "${DEST_DIR}/build/bin/llama-cli" \
        "${DEST_DIR}/build/bin/llama-server" \
        "${DEST_DIR}/build/bin/server" \
        "${DEST_DIR}/build/bin/llama-simple" \
        "${DEST_DIR}/build/bin/llama-bench"; do
        if [ -f "${candidate}" ]; then
            FOUND_BINS+=("${candidate}")
            if command -v strip >/dev/null 2>&1; then
                run_with_spinner_arr "strip $(basename "${candidate}")" -- strip -s "${candidate}" || true
            fi
        fi
    done

    if [ "${#FOUND_BINS[@]}" -eq 0 ]; then
        warn "Build finished but no expected binaries found in build/bin"
        log_file "binaries: $(ls -1 build/bin 2>/dev/null || true)"
        fail_step "llama build: binary not found"
        return 1
    fi

    local build_info="${DEST_DIR}/build/BUILD_INFO.txt"
    {
        printf '%s\n' "commit: $(git -C "${DEST_DIR}" rev-parse --short HEAD 2>/dev/null || echo unknown)"
        printf '%s\n' "cmake_args: ${CMAKE_ARGS}"
        printf '%s\n' "cflags: ${CFLAGS}"
        printf '%s\n' "built_targets: ${BUILT_TARGETS[*]:-generic-build}"
        printf '%s\n' "binaries:"
        printf '  - %s\n' "${FOUND_BINS[@]}"
    } > "${build_info}" || true

    echo ""
    info "llama.cpp build finished"
    printf 'Built binaries:\n'
    printf '  - %s\n' "${FOUND_BINS[@]}"
}

main "$@"
