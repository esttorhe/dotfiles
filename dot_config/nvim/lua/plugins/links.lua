return {
  "jghauser/follow-md-links.nvim",
  ft = "markdown",
  init = function()
    vim.keymap.set("n", "<bs>", ":edit #<cr>", { silent = true })
  end,
}
