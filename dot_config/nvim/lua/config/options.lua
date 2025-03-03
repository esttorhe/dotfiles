-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.opt.winbar = "%=%f %m %r%w%h%=%l/%L %p%%"

vim.opt.statuscolumn = "%@SignCb@%s%=%T%@NumCb@%l %r│%T"

vim.wo.relativenumber = false

vim.g.vim_markdown_folding_disabled = 1
