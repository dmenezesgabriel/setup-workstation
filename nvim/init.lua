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
vim.opt.backup = true              -- keep backup files
vim.opt.swapfile = true            -- keep swap files
vim.opt.updatetime = 300           -- faster completion
vim.opt.timeoutlen = 500           -- key timeout duration
vim.opt.ttimeoutlen = 0            -- key code timeout
vim.opt.autoread = true            -- autoread files changed outside vim

-- clipboard
vim.opt.clipboard = "unnamedplus"  -- system clipboard

-- completion
vim.opt.wildmenu = true            -- enhanced command-line completion
vim.opt.completeopt = {
    "menuone",
    "noinsert",
    "noselect",
}

vim.opt.iskeyword:append("-")      -- treat dash as part of word

vim.g.mapleader = " "
vim.opt.lazyredraw = true          -- don't redraw during macros
vim.opt.synmaxcol = 300            -- syntax highlight limit
vim.opt.encoding = "UTF-8"
