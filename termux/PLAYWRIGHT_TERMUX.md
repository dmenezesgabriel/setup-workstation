# Playwright on Termux (Chromium)

This document explains how to use Playwright on Termux (Android) by using the Termux-provided Chromium build and a small shim so Playwright's Node library runs on Android.

Summary
- Playwright expects to run on Linux (glibc) and rejects process.platform === 'android'.
- You can install Playwright but skip automatic browser downloads (PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1) and point Playwright to a Termux Chromium binary via executablePath.
- A small JavaScript shim that makes `process.platform` return `'linux'` allows Playwright code paths to run on Termux.
- Alternatively you may place a Chromium binary into Playwright's expected cache layout and set `PLAYWRIGHT_BROWSERS_PATH`, but `executablePath` is simpler and more reliable.

Files and artifacts
- Script: `scripts/11-playwright-chromium.sh` — automates installation of Node (if missing), x11-repo, Chromium, installs Playwright (skip browsers), creates the shim and an example project.
- Shim: `~/android-as-linux.js` — created by the script, preloaded to make Playwright think it's on Linux.
- Example project: `~/pw-test/example.js` — example script that launches Chromium via `executablePath`.

Installation (what the script does)
1. Ensures Node.js (nodejs-lts or nodejs) is installed via Termux `pkg`.
2. Enables `x11-repo` and installs `chromium` (GTK + mesa + many dependencies).
3. Installs Playwright while skipping browser downloads:

   PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install -g playwright

4. Creates `~/android-as-linux.js` with:

```js
Object.defineProperty(process, 'platform', {
  get() { return 'linux' }
});
```

5. Creates an example project `~/pw-test` and installs `playwright` locally (skip browsers), and writes `example.js`.

How to run the example
- One-shot (recommended):

  NODE_OPTIONS='--require $HOME/android-as-linux.js' node ~/pw-test/example.js

- Or run directly (the example requires the shim explicitly at the top so NODE_OPTIONS is optional):

  node ~/pw-test/example.js

(If you use a different chromium binary path, set the `CHROME` environment variable before running.)

Why the shim works
- Playwright's JavaScript contains platform-specific checks that currently treat `process.platform === 'android'` as unsupported. The shim sets `process.platform` to `'linux'` early so Playwright's registry and server code use Linux logic.
- The shim must be executed before Playwright is required. Use `NODE_OPTIONS='--require /path/to/android-as-linux.js'` or `require('/path/to/android-as-linux.js')` at the top of your script.

Using the Termux Chromium without the shim (alternative)
- You can instruct Playwright to use the system Chromium binary directly by passing `executablePath` in `chromium.launch({ executablePath: '/path/to/chrome' })` — this avoids Playwright's browser cache entirely.
- The example script uses executablePath for that reason:

```js
const browser = await chromium.launch({
  executablePath: '/data/data/com.termux/files/usr/lib/chromium/chrome',
  headless: true,
  args: ['--no-sandbox', '--disable-dev-shm-usage']
});
```

Setting PLAYWRIGHT_BROWSERS_PATH and symlink approach (advanced)
- Playwright caches browser binaries under `~/.cache/ms-playwright` (or `node_modules/playwright-core/.local-browsers`).
- If you want Playwright to *see* the Termux Chromium as if it was an installed Playwright browser, create the expected layout and symlink the Termux `chrome` ELF as `.../chrome-linux/chrome`.

Example layout:

```
~/.cache/ms-playwright/
└── chromium-system/
    └── chrome-linux/
        └── chrome  (symlink to /data/data/.../lib/chromium/chrome)
```

Then export:

```sh
export PLAYWRIGHT_BROWSERS_PATH="$HOME/.cache/ms-playwright"
```

Finally `npx playwright install --list` should show installed browsers (Playwright may still perform some checks).

Notes & caveats
- Disk and dependencies: Installing `chromium` via Termux pulls many GTK/mesa/X11 packages and requires significant disk space (hundreds of MB). Confirm available storage.
- Browser compatibility: The Termux Chromium is built for Android/Bionic and may differ from Playwright-distributed glibc builds; using `executablePath` bypasses this mismatch.
- Security: Do not globally override `process.platform` across your system unless you understand consequences. Prefer requiring the shim for specific runs only.
- Headless flags: when running headless, use `--no-sandbox --disable-dev-shm-usage --disable-setuid-sandbox` if you face sandboxing or permission issues.
- Playwright MCP / remote scenarios: If you prefer not to run browsers on-device, consider running Playwright (and MCP) on a remote Linux host and connect from Termux.

Troubleshooting
- If Playwright throws `Unsupported platform: android` -> ensure shim runs before Playwright is required (NODE_OPTIONS or require shim at top).
- If Chromium fails to start -> run the chromium binary directly with `--headless --disable-gpu --dump-dom https://example.com` to see errors.
- Check binary type: `file /data/data/.../lib/chromium/chrome` -> should show ELF for aarch64.
- Check Node: `node --version` (Playwright supports modern Node 18/20/22+; Node 20+ is recommended).

Example quick commands

```sh
# install (script will perform these)
pkg update -y
pkg install nodejs-lts x11-repo -y
pkg install chromium -y
PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install -g playwright

# run example
NODE_OPTIONS='--require $HOME/android-as-linux.js' node ~/pw-test/example.js
```

If you want a helper wrapper
- You can create a small wrapper at `~/.local/bin/pw-run` to run Playwright scripts with the shim preloaded:

```sh
#!/bin/sh
NODE_OPTIONS='--require "$HOME/android-as-linux.js"' node "$@"
```

Make it executable and call `pw-run ~/pw-test/example.js`.

Support & references
- Playwright browsers doc: https://playwright.dev/docs/browsers
- Playwright installation doc: https://playwright.dev/docs/intro

If you want, I can:
- add the wrapper to the install script or persist environment variables to your shell rc files,
- or implement the symlink-based PLAYWRIGHT_BROWSERS_PATH layout as an option in the script.
