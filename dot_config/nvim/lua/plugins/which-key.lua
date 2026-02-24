-- ABOUTME: which-key.nvim popup that shows available keybindings as you type
-- ABOUTME: Press <leader>? to see all keymaps, auto-shows after delay on leader key
return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  config = function()
    local wk = require("which-key")

    wk.setup({
      preset = "modern",
      delay = 300, -- delay before which-key popup appears
      icons = {
        breadcrumb = "»", -- symbol used in the command line area
        separator = "➜", -- symbol used between a key and it's label
        group = "+", -- symbol prepended to a group
      },
      win = {
        border = "rounded",
        padding = { 1, 2 },
      },
    })

    -- Register leader key groups for better organization
    wk.add({
      { "<leader>p", group = "Project/Files" },
      { "<leader>c", group = "Code" },
      { "<leader>r", group = "Rename" },
      { "<leader>d", group = "Diagnostics/Diff" },
      { "<leader>g", group = "Git" },
      { "<leader>F", desc = "Format buffer" },
    })

    -- Bind leader+? to show all keymaps
    vim.keymap.set("n", "<leader>?", function()
      wk.show({ global = true })
    end, { desc = "Show keymaps cheatsheet" })
  end,
}
