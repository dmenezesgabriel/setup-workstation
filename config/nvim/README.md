# Nvim

## Install

**From this repo** (run from repo root):

```sh
rsync -a --delete config/nvim/ ~/.config/nvim/
```

**Without cloning** (one-liner):

```sh
git clone --depth 1 --filter=blob:none --sparse https://github.com/dmenezesgabriel/setup-workstation /tmp/nvim-setup && git -C /tmp/nvim-setup sparse-checkout set config/nvim && rsync -a /tmp/nvim-setup/config/nvim/ ~/.config/nvim/ && rm -rf /tmp/nvim-setup
```

---

```sh
nvim -u init.lua init.lua
```

## Commands

### Explore

Sidebar file explorer

- `<leader>e`: toggle the sidebar explorer
- `:SidebarToggle`: toggle the sidebar explorer
- `<CR>` or `l`: expand a directory or open a file
- `h`: collapse an expanded directory or move to the parent entry
- `r`: refresh the sidebar tree and recalculate git-ignored styling
- `q`: close the sidebar

The explorer opens from the project root when a root marker is found, otherwise from the current working directory.
Directories use `▸` and `▾` markers so the tree stays readable without plugins.
Git-ignored files and directories are shown with a muted gray highlight when the current root is inside a git repository.

### Functioning

- `:healthcheck`

### Config

- `:so`: source init.lua file

### Process

- `CTRL + Z`: Suspend process
- `fg`: back to process

## References

- [nvim-lite](https://github.com/radleylewis/nvim-lite/blob/youtube_demo/init.lua)
