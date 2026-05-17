Implemented `issues/001-add-native-nvim-sidebar-file-explorer.md`.

Changed files:
- `config/nvim/init.lua`
- `config/nvim/lua/sidebar_explorer.lua`
- `config/nvim/README.md`
- `config/nvim/tests/sidebar_explorer_validation.lua`
- `implementation/001-add-native-nvim-sidebar-file-explorer-summary.md`
- `implementation/001-worker-report.md`

Validation:
- `git diff --check` — passed
- `command -v nvim` — `nvim` not available in this environment
- `command -v luac` — `luac` not available in this environment
- Reviewed the headless validation artifact at `config/nvim/tests/sidebar_explorer_validation.lua`

Open risks/questions:
- Neovim runtime validation is still required on a machine with `nvim` installed, especially for the sidebar window lifecycle and buffer-local mappings.
- This working tree already contains unrelated pre-existing changes (`scripts/process_audit.py` deleted and planning/artifact files untracked); they were not modified as part of this task.

Recommended next step:
- Run `cd config/nvim && nvim --headless -u init.lua "+luafile tests/sidebar_explorer_validation.lua" +q` and then manually smoke-test `<leader>e`, `<CR>`, `h`, `r`, and `q` in Neovim.
