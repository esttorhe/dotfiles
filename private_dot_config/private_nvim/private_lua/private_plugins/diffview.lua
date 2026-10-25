-- ABOUTME: diffview.nvim for side-by-side git diffs and file history
-- ABOUTME: Open with <leader>dv, close with <leader>dc, file history with <leader>dh
return {
  "sindrets/diffview.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
  keys = {
    { "<leader>dv", "<cmd>DiffviewOpen<CR>", desc = "Open Diffview" },
    { "<leader>dc", "<cmd>DiffviewClose<CR>", desc = "Close Diffview" },
    { "<leader>dh", "<cmd>DiffviewFileHistory<CR>", desc = "Diffview File History" },
    { "<leader>df", "<cmd>DiffviewFileHistory %<CR>", desc = "Diffview Current File History" },
  },
  config = function()
    local actions = require("diffview.actions")

    require("diffview").setup({
      enhanced_diff_hl = true, -- See ':h diffview-config-enhanced_diff_hl'
      view = {
        default = {
          layout = "diff2_horizontal",
        },
        merge_tool = {
          layout = "diff3_horizontal",
        },
      },
      file_panel = {
        listing_style = "tree", -- 'list' or 'tree'
        win_config = {
          position = "left",
          width = 35,
        },
      },
      keymaps = {
        view = {
          { "n", "<Esc>", "<Cmd>DiffviewClose<CR>", { desc = "Close Diffview" } },
          { "n", "gf", actions.goto_file_edit, { desc = "Open file in buffer" } },
        },
        file_panel = {
          { "n", "<Esc>", "<Cmd>DiffviewClose<CR>", { desc = "Close Diffview" } },
          { "n", "gf", actions.goto_file_edit, { desc = "Open file in buffer" } },
        },
      },
    })
  end,
}
