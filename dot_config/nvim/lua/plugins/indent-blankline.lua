return {
  "lukas-reineke/indent-blankline.nvim",
  main = "ibl",
  event = "VeryLazy",
  dependencies = {
    "HiPhish/rainbow-delimiters.nvim",
  },
  config = function()
    local highlight = {
      "RainbowDelimiterRed",
      "RainbowDelimiterYellow",
      "RainbowDelimiterGreen",
      "RainbowDelimiterCyan",
      "RainbowDelimiterBlue",
      "RainbowDelimiterViolet",
    }

    require("ibl").setup({
      indent = {
        char = "▏",
      },
      scope = {
        enabled = true,
        show_start = false,
        show_end = false,
        include = {
          node_type = { ["*"] = { "*" } },
        },
        highlight = highlight,
      },
    })

    local hooks = require("ibl.hooks")
    -- Use rainbow-delimiters to determine scope color
    hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
  end,
}
