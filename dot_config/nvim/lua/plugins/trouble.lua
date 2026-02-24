-- ABOUTME: trouble.nvim for a pretty list of diagnostics, references, and quickfix
-- ABOUTME: Toggle with <leader>xx for all diagnostics, <leader>xX for buffer-only
return {
  "folke/trouble.nvim",
  opts = {
    modes = {
      -- Custom mode for showing diagnostics at cursor
      diagnostics_cursor = {
        mode = "diagnostics",
        filter = {
          any = {
            buf = 0, -- current buffer only
            {
              severity = vim.diagnostic.severity.HINT,
              function(item)
                return item.pos[1] == vim.fn.line(".") - 1
              end,
            },
          },
        },
        preview = {
          type = "float",
          border = "rounded",
          title = "Diagnostic Preview",
          title_pos = "center",
          position = { 0, -2 },
          size = { width = 0.4, height = 0.3 },
          zindex = 200,
        },
      },
    },
  },
  cmd = "Trouble",
  keys = {
    {
      "<leader>xx",
      "<cmd>Trouble diagnostics toggle<cr>",
      desc = "Diagnostics (Trouble)",
    },
    {
      "<leader>xX",
      "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
      desc = "Buffer Diagnostics (Trouble)",
    },
    {
      "<leader>cs",
      "<cmd>Trouble symbols toggle focus=false<cr>",
      desc = "Symbols (Trouble)",
    },
    {
      "<leader>cl",
      "<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
      desc = "LSP Definitions / references / ... (Trouble)",
    },
    {
      "<leader>xL",
      "<cmd>Trouble loclist toggle<cr>",
      desc = "Location List (Trouble)",
    },
    {
      "<leader>xQ",
      "<cmd>Trouble qflist toggle<cr>",
      desc = "Quickfix List (Trouble)",
    },
  },
}
