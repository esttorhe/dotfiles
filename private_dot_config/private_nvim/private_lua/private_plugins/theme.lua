-- ABOUTME: Catppuccin Mocha theme configuration
-- ABOUTME: Provides consistent colors for status line, diagnostics, and UI

return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = true,
      term_colors = true,
      float = {
        transparent = true,
      },
      styles = {
        comments = { "italic" },
        keywords = { "italic" },
      },
      lsp_styles = {
        -- Undercurl reads better than a flat underline against the palette.
        underlines = {
          errors = { "undercurl" },
          warnings = { "undercurl" },
          information = { "undercurl" },
          hints = { "undercurl" },
          ok = { "undercurl" },
        },
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-mocha",
    },
  },
}
