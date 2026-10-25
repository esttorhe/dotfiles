-- ABOUTME: aerial.nvim code outline sidebar
-- ABOUTME: Toggle with <leader>o for function/class structure view

return {
  "stevearc/aerial.nvim",
  lazy = true,
  cmd = { "AerialToggle", "AerialOpen" },
  keys = {
    { "<leader>o", "<cmd>AerialToggle<CR>", desc = "Toggle outline" },
    { "<leader>O", "<cmd>AerialNavToggle<CR>", desc = "Toggle nav outline" },
  },
  opts = {
    layout = {
      min_width = 30,
      default_direction = "prefer_right",
    },
    on_attach = function(bufnr)
      -- Jump to symbol on Enter
      vim.keymap.set("n", "<CR>", "<cmd>AerialNext<CR>", { buffer = bufnr })
      -- Navigate with h/l
      vim.keymap.set("n", "h", "<cmd>AerialPrev<CR>", { buffer = bufnr })
      vim.keymap.set("n", "l", "<cmd>AerialNext<CR>", { buffer = bufnr })
    end,
    close_on_select = false,
    highlight_on_jump = 300,
    backends = { "lsp", "treesitter", "markdown", "man" },
    filter_kind = {
      "Class",
      "Constructor",
      "Enum",
      "Function",
      "Interface",
      "Module",
      "Method",
      "Struct",
    },
  },
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },
}
