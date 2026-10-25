-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.wo.relativenumber = true -- Show relative line numbers
vim.opt.guioptions:remove("T") -- Remove toolbar
