return {
  "nvim-treesitter/nvim-treesitter",
  version = false, -- last release is way too old and doesn't work on Windows
  opts = function(_, opts)
    if type(opts.ensure_installed) == "table" then
      vim.list_extend(opts.ensure_installed, {
        "json",
        "json5",
        "jsonc",
        "typescript",
        "tsx",
        "bash",
        "json",
        "lua",
        "markdown",
        "markdown_inline",
        "go",
        "query",
        "regex",
        "vim",
      })
    end
  end,
}
