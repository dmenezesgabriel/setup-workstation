#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail

# Installs Chromium (Termux/x11-repo), Node (if missing) and Playwright (skip browser downloads),
# creates a small example project and a process.platform shim to allow Playwright to run on Android.
# Idempotent where reasonable; safe to re-run.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_SH="${RUN_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}/lib.sh"
# shellcheck disable=SC1091
source "${LIB_SH}"

main() {
    echo -e "${PURPLE}Playwright + Chromium setup for Termux${NC}"
    echo ""

    if [ "${DRY_RUN:-0}" = "1" ]; then
        log_debug "DRY_RUN: would install Chromium, Node and Playwright"
        return 0
    fi

    # Ensure basic packages
    log_file "playwright-termux: ensure node and x11 repo"

    if pkg_available "nodejs-lts"; then
        pkg_install "nodejs-lts" "Node.js (LTS)"
    else
        pkg_install "nodejs" "Node.js"
    fi

    # X11 repo is needed for Chromium
    pkg_install "x11-repo" "Termux X11 repo"

    # Update package lists once more before large install
    run_with_spinner_arr "apt: update" -- pkg update -y || true

    # Install Chromium (will pull many dependencies including GTK/mesa)
    pkg_install "chromium" "Chromium"

    # Detect chromium executable (prefer the real ELF binary)
    local wrapper realbin
    wrapper="$(command -v chromium 2>/dev/null || command -v chromium-browser 2>/dev/null || true)"
    if [ -z "${wrapper}" ]; then
        warn "Chromium wrapper not found in PATH; installation may have failed."
    else
        log_debug "Chromium wrapper: ${wrapper}"
        realbin="$(readlink -f "${wrapper}" 2>/dev/null || printf '%s' "${wrapper}")"
        log_file "Chromium binary (resolved): ${realbin}"
        info "Detected Chromium binary: ${realbin}"
    fi

    # Install Playwright (skip browser downloads) globally to provide npx/playwright commands
    if command -v npm >/dev/null 2>&1; then
        log_file "Installing Playwright (global, skip browser downloads)"
        if ! run_with_spinner_arr "npm: playwright (global)" -- env PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install -g --no-audit --no-fund playwright; then
            warn "Global playwright install failed — continuing and attempting local project install"
        fi
    else
        fail_step "npm not found; cannot install Playwright via npm"
    fi

    # Create a small example project with local Playwright (skip browser downloads)
    local projdir="${HOME}/pw-test"
    mkdir -p "${projdir}" || true
    if [ ! -f "${projdir}/package.json" ]; then
        printf '{"name":"pwtest","version":"1.0.0"}\n' > "${projdir}/package.json"
    fi

    pushd "${projdir}" >/dev/null 2>&1 || true
    if command -v npm >/dev/null 2>&1; then
        log_file "Installing Playwright in project ${projdir} (skip browser downloads)"
        env PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install --no-audit --no-fund playwright@latest || warn "project npm install failed"
    fi
    popd >/dev/null 2>&1 || true

    # Create the process.platform shim (idempotent)
    local shim="${HOME}/android-as-linux.js"
    if [ -f "${shim}" ]; then
        log_debug "shim exists: ${shim} (skipping overwrite)"
    else
        cat > "${shim}" <<'JS'
Object.defineProperty(process, 'platform', {
  get() {
    return 'linux'
  }
});
JS
        chmod 644 "${shim}" 2>/dev/null || true
        info "Created platform shim: ${shim} (preload with NODE_OPTIONS='--require ${shim}')"
    fi

    # Create an example script that requires the shim first and uses the detected chromium
    local example_js="${HOME}/pw-test/example.js"
    cat > "${example_js}" <<'JS'
// Example Playwright script for Termux Chromium
// It requires the platform shim before loading Playwright.
require(process.env.PLATFORM_SHIM || process.env.HOME + '/android-as-linux.js');
const { chromium } = require('playwright');
(async () => {
  const exe = process.env.CHROME || '/data/data/com.termux/files/usr/lib/chromium/chrome';
  console.log('Using executable:', exe);
  const browser = await chromium.launch({
    executablePath: exe,
    headless: true,
    args: ['--no-sandbox', '--disable-dev-shm-usage', '--disable-setuid-sandbox']
  });
  const page = await browser.newPage();
  await page.goto('https://www.example.com', { waitUntil: 'domcontentloaded', timeout: 30000 });
  console.log('TITLE:', await page.title());
  await browser.close();
})();
JS
    chmod 644 "${example_js}" 2>/dev/null || true

    info "Playwright + Chromium setup complete. Example script: ${example_js}"

    echo ""
    echo "Run the example (one-shot, does not require modifying shells):"
    echo "  NODE_OPTIONS='--require ${shim}' node ${example_js}"
    echo "Or run without NODE_OPTIONS if you set PLATFORM_SHIM env or require the shim at top of your own scripts."
    echo "If you prefer Playwright to look for system-installed browsers, use 'executablePath' in launch options or set PLAYWRIGHT_BROWSERS_PATH to a cache layout and symlink the chromium binary into it. See PLAYWRIGHT_TERMUX.md for details."

}

main "$@"
