-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.winbar = "%=%f %m %r%w%h%=%l/%L %p%%"

vim.clipboard = "unnamedplus"

vim.opt.statuscolumn = "%@SignCb@%s%=%T%@NumCb@%l %r│%T"

vim.wo.relativenumber = false

vim.g.vim_markdown_folding_disabled = 1

local homedir = os.getenv("HOME")

vim.opt.spelllang = { "en" }

vim.g.mapleader = ","
vim.g.maplocalleader = ","

vim.g.vim_markdown_folding_disabled = 1

vim.wo.wrap = true
vim.wo.linebreak = true
vim.wo.list = false

vim.opt.list = false
vim.opt.listchars = "tab:>·,trail:~,extends:>,precedes:<,space:␣,eol:¬"

vim.opt.colorcolumn = "79,119"

-- vim.opt.number = true
-- vim.opt.relativenumber = true
-- vim.opt.signcolumn = "number"
vim.opt.statuscolumn = "%@SignCb@%s%=%T%@NumCb@%l %r│%T"

if vim.g.neovide then
  vim.o.guifont = "FiraCode Nerd Font Propo:h16"
end
