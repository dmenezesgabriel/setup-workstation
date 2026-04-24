-- syntax highlighting
vim.cmd("syntax on")
vim.cmd.colorscheme("slate")       -- default, desert, elflord, morning, murphy, ron, shine, slate, torte, zellner
vim.opt.termguicolors = true       -- enable 24-bit colors

-- ruler
vim.opt.signcolumn = "yes"         -- show sign column
vim.opt.colorcolumn = "80,100"     -- show column at 80 characters
vim.api.nvim_set_hl(
    0,
    "ColorColumn",
    {
        ctermbg = 0,
        bg = "#2a2a2a"
    }
)

-- brackets
vim.opt.showmatch = true           -- highlight matching brackets

-- layout
vim.opt.cmdheight = 1
vim.opt.pumheight = 10             -- popup menu height
vim.opt.pumblend = 10              -- popup menu transparency
vim.opt.winblend = 0               -- floating window transparency

-- wrap
vim.opt.wrap = false               -- don't wrap lines

-- scrolling
vim.opt.scrolloff = 10             -- keep 10 lines above/ below cursor
vim.opt.sidescrolloff = 8          -- keep 8 columns left/right of cursor

-- line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- status line
vim.opt.showcmd = true             -- show command in status line
vim.opt.ruler = true               -- show line/ column in status line

-- cursor
vim.opt.cursorline = true

-- Window splitting
vim.opt.splitbelow = true
vim.opt.splitright = true

-- tab size
vim.opt.tabstop = 4                -- spaces per tab
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4             -- spaces per indent
vim.opt.expandtab = true           -- use spaces
vim.opt.smartindent = true         -- smart auto-indent
vim.opt.autoindent = true          -- copy indent from current line

-- buffer
vim.opt.hidden = true              -- allow switching buffers without saving

-- mouse
vim.opt.mouse = "a"                -- enable mouse

-- search
vim.opt.ignorecase = true
vim.opt.smartcase = true           -- override ignorecase if search has capitals
vim.opt.incsearch = true           -- show matches while typing
vim.opt.hlsearch = true            -- highlight all search matches
vim.opt.path:append("**")          -- include subdirectories in search

-- files and performance
vim.opt.undofile = true            -- persist undo
vim.opt.undodir = vim.fn.expand(   -- undo directory
    "~/.vim/undodir"
)
vim.opt.backup = false             -- don't create backup files
vim.opt.writebackup = false        -- don't create backup before writing
vim.opt.swapfile = false           -- don't keep swap files
vim.opt.updatetime = 300           -- faster completion
vim.opt.timeoutlen = 500           -- key timeout duration
vim.opt.ttimeoutlen = 0            -- key code timeout
vim.opt.autoread = true            -- autoread files changed outside vim

-- clipboard
vim.opt.clipboard = "unnamedplus"  -- system clipboard

-- completion
vim.opt.wildmenu = true            -- enhanced command-line completion
vim.opt.wildmode = "longest:full,full"
vim.opt.wildignore:append(
    {
        "*.o",
        "*.obj",
        "*.pyc",
        "*.class",
        "*.jar",
    }
)
vim.opt.completeopt = {
    "menuone",
    "noinsert",
    "noselect",
}

vim.opt.iskeyword:append("-")      -- treat dash as part of word

vim.g.mapleader = " "              -- set leader key to space
vim.opt.lazyredraw = true          -- don't redraw during macros
vim.opt.synmaxcol = 300            -- syntax highlight limit
vim.opt.encoding = "UTF-8"

-- performance improvements
vim.opt.redrawtime = 10000
vim.opt.maxmempattern = 20000

-- tabs
vim.opt.showtabline = 1            -- always show tabline
vim.opt.tabline = ""               -- use default tabline


-- ===========================================================================
-- Functions
-- ===========================================================================

-- Basic autocommands
local augroup = vim.api.nvim_create_augroup("UserConfig", {})

-- copy full file path
-- space + pa + '+'
vim.keymap.set(
    "n",
    "<leader>pa",
    function()
       local path = vim.fn.expand("%:p")
       vim.fn.setreg("+", path)
       print("file:", path)
   end
)


-- return to last position when opening files
vim.api.nvim_create_autocmd("BufReadPost", {
        group = augroup,
        callback = function()
            local mark = vim.api.nvim_buf_get_mark(0, '"')
            local lcount = vim.api.nvim_buf_line_count(0)
            if mark[1] > 0 and mark[1] <= lcount then
                pcall(vim.api.nvim_win_set_cursor, 0, mark)
            end
        end,
    }
)


-- create directories when saving files
vim.api.nvim_create_autocmd("BufWritePre", {
        group = augroup,
        callback = function()
            local dir = vim.fn.expand("<afile>:p:h")
            if vim.fn.isdirectory(dir) == 0 then
                vim.fn.mkdir(dir, "p")
            end
        end,
    }
)

-- auto-resize splits when window is resized
vim.api.nvim_create_autocmd("VimResized", {
    group = augroup,
    callback = function()
        vim.cmd("tabdo wincmd = ")
    end,
})

-- creatre undo directory if it does not exist
local undodir = vim.fn.expand("~/.vim/undodir")
if vim.fn.isdirectory(undodir) == 0 then
    vim.fn.mkdir(undodir, "p")
end

-- Function to find project root
local function find_root(patterns)
  local path = vim.fn.expand('%:p:h')
  local root = vim.fs.find(patterns, { path = path, upward = true })[1]
  return root and vim.fn.fnamemodify(root, ':h') or path
end

-- ===========================================================================
-- Language options
-- ===========================================================================

vim.api.nvim_create_autocmd("FileType", {
    group = augroup,
    pattern = { "lua", "python" },
    callback = function()
        vim.opt_local.tabstop = 4
        vim.opt_local.shiftwidth = 4
    end,
})


vim.api.nvim_create_autocmd("FileType", {
    group = augroup,
    pattern = { "javascript", "typescript", "json", "html", "css" },
    callback = function()
        vim.opt_local.tabstop = 2
        vim.opt_local.shiftwidth = 2
    end,
})

-- ===========================================================================
-- LSP
-- ===========================================================================

-- Python LSP setup
local function setup_python_lsp()
  vim.lsp.start({
    name = 'pylsp',
    cmd = {
        vim.fn.expand(
        "~/environments/general/bin/pylsp" -- install "python-lsp-server[all]"
        )
    },
    filetypes = {'python'},
    root_dir = find_root({
        'pyproject.toml',
        'setup.py',
        'setup.cfg',
        'requirements.txt',
        '.git'
    }),
    settings = {
      pylsp = {
        plugins = {
          pycodestyle = {
              enabled = false
          },
          flake8 = {
              enabled = true,
          },
          black = {
              enabled = true
          },
          jedi_completion = {
            enabled = true
          },
        }
      }
    }
  })
end

-- Auto-start LSPs based on filetype
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'python',
  callback = setup_python_lsp,
  desc = 'Start Python LSP'
})


-- LSP keymaps
vim.api.nvim_create_autocmd('LspAttach', {
  callback = function(ev)
    local opts = { buffer = ev.buf }

    -- Set omnifunc to use LSP
    vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

    -- Go to definition
    vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)

    -- Go to declaration
    vim.keymap.set('n', 'gs', vim.lsp.buf.declaration, opts)

    -- Show references
    vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)

    -- Hover docs
    vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)

    -- Go to implementation
    vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)

    -- Signature help
    vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)

    -- Rename symbol
    vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)

    -- Code actions
    vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)

    -- Trigger completion
    vim.keymap.set('i', '<C-Space>', '<C-x><C-o>', opts)
end,
})

-- LSP Info command
vim.api.nvim_create_user_command('LspInfo', function()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients == 0 then
    print("No LSP clients attached to current buffer")
  else
    for _, client in ipairs(clients) do
      print("LSP: " .. client.name .. " (ID: " .. client.id .. ")")
    end
  end
end, { desc = 'Show LSP client info' })
