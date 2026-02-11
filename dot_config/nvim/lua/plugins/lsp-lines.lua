-- ABOUTME: lsp_lines.nvim for virtual line diagnostics
-- ABOUTME: Shows full error messages as lines below code (toggle with <leader>l)

return {
  "https://git.sr.ht/~whynothugo/lsp_lines.nvim",
  event = "LspAttach",
  config = function()
    -- Disable native virtual_text since lsp_lines will handle it
    vim.diagnostic.config({
      virtual_text = false,
      virtual_lines = true,
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = "",
          [vim.diagnostic.severity.WARN] = "",
          [vim.diagnostic.severity.INFO] = "",
          [vim.diagnostic.severity.HINT] = "",
        },
        numhl = {
          [vim.diagnostic.severity.ERROR] = "DiagnosticError",
          [vim.diagnostic.severity.WARN] = "DiagnosticWarn",
          [vim.diagnostic.severity.INFO] = "DiagnosticInfo",
          [vim.diagnostic.severity.HINT] = "DiagnosticHint",
        },
      },
      underline = {
        severity = {
          vim.diagnostic.severity.ERROR,
          vim.diagnostic.severity.WARN,
          vim.diagnostic.severity.INFO,
          vim.diagnostic.severity.HINT,
        },
      },
      update_in_insert = true,
      severity_sort = true,
    })

    require("lsp_lines").setup()

    -- Tokyo Night colors for virtual text
    vim.api.nvim_set_hl(0, "DiagnosticVirtualTextError", { fg = "#db4b4b", bg = "#1a1b26" })
    vim.api.nvim_set_hl(0, "DiagnosticVirtualTextWarn", { fg = "#e0af68", bg = "#1a1b26" })
    vim.api.nvim_set_hl(0, "DiagnosticVirtualTextInfo", { fg = "#0db9d7", bg = "#1a1b26" })
    vim.api.nvim_set_hl(0, "DiagnosticVirtualTextHint", { fg = "#1abc9c", bg = "#1a1b26" })

    -- Toggle lsp_lines with <leader>l
    vim.keymap.set("", "<leader>l", function()
      local config = vim.diagnostic.config() or {}
      if config.virtual_lines then
        vim.diagnostic.config({ virtual_lines = false, virtual_text = true })
      else
        vim.diagnostic.config({ virtual_lines = true, virtual_text = false })
      end
    end, { desc = "Toggle lsp_lines" })
  end,
}
