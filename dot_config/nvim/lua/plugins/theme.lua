-- ABOUTME: Tokyo Night Moon theme configuration
-- ABOUTME: Provides consistent colors for status line, diagnostics, and UI

return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "moon",
      transparent = true,
      terminal_colors = true,
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
        sidebars = "transparent",
        floats = "transparent",
      },
      on_highlights = function(hl, c)
        -- Custom diagnostic underlines with Tokyo Night colors
        hl.DiagnosticUnderlineError = { undercurl = true, sp = c.red }
        hl.DiagnosticUnderlineWarn = { undercurl = true, sp = c.yellow }
        hl.DiagnosticUnderlineInfo = { undercurl = true, sp = c.cyan }
        hl.DiagnosticUnderlineHint = { undercurl = true, sp = c.teal }
      end,
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "tokyonight-moon",
    },
  },
}
