" vim -u .vimrc

" Encoding
set encoding=UTF-8

" Don't act like vi
set nocompatible

" Enable mouse
set mouse=a

" Indentation size
set tabstop=2

" Identify file type and apply indentation
filetype plugin indent on

" Apply colors on editor
syntax on

" Use same tabstop size to indent visually
set shiftwidth=2

" Backspace usual behaviour
set backspace=2

set laststatus=2

" Show line numbers
set number

" Highlight cursor line
set cursorline

" Show Mode
set showmode

" Calculate relative line distance
set relativenumber

" Search incremental feedback
set incsearch

" Highlight search results
set hlsearch

"Remove pipes vertical separator
set smartindent

"Remove pipes vertical separator
augroup nosplit | au!
  autocmd ColorScheme * hi VertSplit ctermfg=black guifg=black guibg=black ctermbg=black
augroup end

" 256 color support for terminal
set t_Co=256

" Use spaces instead of tabs
set expandtab
set softtabstop=2

" Spell checking
set spell spelllang=en_us

" Highlight trailing spaces
highlight RedundantSpaces ctermbg=red guibg=red
match RedundantSpaces /\s\+$/
au BufRead, BufNewFile *.py,*.pyw,*.c,*.h match BadWhitespace /\s\+$/

" System clipboard
set clipboard=unnamed

" Indentation

" Python
au BufNewFile, BufRead *.py
    \ set tabstop=4
    \ | set softtabstop=4
    \ | set shiftwidth=4
    \ | set textwidth=79
    \ | set expandtab
    \ | set autoindent
    \ | set fileformat=unix

" Typescript
" tsconfig.json is actually jsonc, help TypeScript set the correct filetype
autocmd BufRead,BufNewFile tsconfig.json set filetype=jsonc

" Web
au BufNewFile,BufRead *.js, *.html, *.css
    \ set tabstop=2
    \ | set softtabstop=2
    \ | set shiftwidth=2

" Auto close brackets
noremap " ""<left>
inoremap ' ''<left>
inoremap ( ()<left>
inoremap [ []<left>
inoremap { {}<left>
inoremap {<CR> {<CR>}<ESC>O
inoremap {;<CR> {<CR>};<ESC>O

" Search down into sub folders and set tab completion for all file related
" tasks
set path+=**

" Display all matching files
set wildmenu

" Syntax Highlight
au BufRead,BufNewFile, *.vue set syntax=html
