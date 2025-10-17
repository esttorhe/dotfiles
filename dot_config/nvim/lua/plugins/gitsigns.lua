return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    require("gitsigns").setup({
      signs = {
        add = { text = "│" },
        change = { text = "│" },
        delete = { text = "_" },
        topdelete = { text = "‾" },
        changedelete = { text = "~" },
      },
      current_line_blame = false, -- enable blame inline
      current_line_blame_opts = {
        delay = 0, -- show immediately
        virt_text_pos = "eol", -- "eol" | "overlay" | "right_align"
      },
      word_diff = true,
      current_line_blame_formatter = "<author>, <author_time:%R> • <summary>",
    })
  end,
}
