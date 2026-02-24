-- ABOUTME: git-conflict.nvim for highlighting and resolving git merge conflicts
-- ABOUTME: Uses default keymaps for choosing ours/theirs/both/none
return {
  "akinsho/git-conflict.nvim",
  version = "*",
  config = function()
    require("git-conflict").setup({
      default_mappings = true,    -- Use default keymaps
      disable_diagnostics = false,
      list_opener = "copen",
      highlights = {
        incoming = "DiffAdd",
        current = "DiffText",
      },
    })
  end,
}
