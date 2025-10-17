return {
  "HiPhish/rainbow-delimiters.nvim",
  event = "VeryLazy",
  config = function()
    local highlight = {
      "RainbowDelimiterRed",
      "RainbowDelimiterYellow",
      "RainbowDelimiterGreen",
      "RainbowDelimiterCyan",
      "RainbowDelimiterBlue",
      "RainbowDelimiterViolet",
    }

    local function setup_highlights()
      -- Define highlight groups for rainbow-delimiters (Tokyo Night Moon)
      vim.api.nvim_set_hl(0, "RainbowDelimiterRed", { fg = "#ff757f" })
      vim.api.nvim_set_hl(0, "RainbowDelimiterYellow", { fg = "#ffc777" })
      vim.api.nvim_set_hl(0, "RainbowDelimiterGreen", { fg = "#c3e88d" })
      vim.api.nvim_set_hl(0, "RainbowDelimiterCyan", { fg = "#89ddff" })
      vim.api.nvim_set_hl(0, "RainbowDelimiterBlue", { fg = "#82aaff" })
      vim.api.nvim_set_hl(0, "RainbowDelimiterViolet", { fg = "#c099ff" })

      -- Configure rainbow-delimiters to use these highlights
      vim.g.rainbow_delimiters = { highlight = highlight }
    end

    -- Setup highlights initially
    setup_highlights()

    -- Re-setup highlights after colorscheme changes
    vim.api.nvim_create_autocmd("ColorScheme", {
      pattern = "*",
      callback = setup_highlights,
    })
  end,
}
