-- ABOUTME: bufferline.nvim for tab bar with Tokyo Night colors
-- ABOUTME: Mouse support, diagnostics indicators, buffer navigation

return {
  "akinsho/bufferline.nvim",
  version = "*",
  dependencies = "nvim-tree/nvim-web-devicons",
  config = function()
    -- Tokyo Night Moon colors for bubble theme
    local colors = {
      bg = "#222436",
      bg_dark = "#1e2030",
      blue = "#82aaff",
      cyan = "#86e1fc",
      fg = "#c8d3f5",
      grey = "#828bb8",
      dark_grey = "#3b4261",
      red = "#ff757f",
      yellow = "#ffc777",
      green = "#c3e88d",
      magenta = "#c099ff",
      teal = "#4fd6be",
      orange = "#ff966c",
    }

    require("bufferline").setup({
      options = {
        mode = "buffers",
        numbers = function(opts)
          return string.format("%s", opts.ordinal)
        end,
        diagnostics = "nvim_lsp",
        diagnostics_indicator = function(count, level, _, _)
          local icon = level:match("error") and " " or " "
          return " " .. icon .. count
        end,
        separator_style = { "", "" },
        show_close_icon = false,
        show_buffer_close_icons = true,
        always_show_bufferline = true,
        hover = {
          enabled = true,
          delay = 150,
          reveal = { "close" },
        },
        indicator = {
          style = "none",
        },
        left_mouse_command = "buffer %d",
        middle_mouse_command = nil,
        right_mouse_command = "bdelete! %d",
        offsets = {
          {
            filetype = "neo-tree",
            text = "Explorer",
            highlight = "Directory",
            separator = true,
          },
        },
      },
      highlights = {
        fill = {
          bg = colors.bg_dark,
        },
        background = {
          bg = colors.bg_dark,
          fg = colors.grey,
        },
        buffer_visible = {
          bg = colors.bg_dark,
          fg = colors.grey,
        },
        buffer_selected = {
          bg = colors.dark_grey,
          fg = colors.blue,
          bold = false,
          italic = false,
        },
        numbers = {
          bg = colors.bg_dark,
          fg = colors.grey,
        },
        numbers_visible = {
          bg = colors.bg_dark,
          fg = colors.grey,
        },
        numbers_selected = {
          bg = colors.dark_grey,
          fg = colors.blue,
          bold = false,
        },
        modified = {
          bg = colors.bg_dark,
          fg = colors.yellow,
        },
        modified_visible = {
          bg = colors.bg_dark,
          fg = colors.yellow,
        },
        modified_selected = {
          bg = colors.dark_grey,
          fg = colors.yellow,
        },
        duplicate = {
          bg = colors.bg_dark,
          fg = colors.grey,
          italic = true,
        },
        duplicate_visible = {
          bg = colors.bg_dark,
          fg = colors.grey,
          italic = true,
        },
        duplicate_selected = {
          bg = colors.dark_grey,
          fg = colors.blue,
          italic = true,
        },
        separator = {
          bg = colors.bg_dark,
          fg = colors.bg_dark,
        },
        separator_visible = {
          bg = colors.bg_dark,
          fg = colors.bg_dark,
        },
        separator_selected = {
          bg = colors.bg_dark,
          fg = colors.bg_dark,
        },
        close_button = {
          bg = colors.bg_dark,
          fg = colors.grey,
        },
        close_button_visible = {
          bg = colors.bg_dark,
          fg = colors.red,
        },
        close_button_selected = {
          bg = colors.dark_grey,
          fg = colors.red,
        },
        diagnostic = {
          bg = colors.bg_dark,
        },
        diagnostic_visible = {
          bg = colors.bg_dark,
        },
        diagnostic_selected = {
          bg = colors.dark_grey,
        },
        error = {
          bg = colors.bg_dark,
          fg = colors.red,
        },
        error_visible = {
          bg = colors.bg_dark,
          fg = colors.red,
        },
        error_selected = {
          bg = colors.dark_grey,
          fg = colors.red,
          bold = false,
        },
        error_diagnostic = {
          bg = colors.bg_dark,
          fg = colors.red,
        },
        error_diagnostic_visible = {
          bg = colors.bg_dark,
          fg = colors.red,
        },
        error_diagnostic_selected = {
          bg = colors.dark_grey,
          fg = colors.red,
          bold = false,
        },
        warning = {
          bg = colors.bg_dark,
          fg = colors.yellow,
        },
        warning_visible = {
          bg = colors.bg_dark,
          fg = colors.yellow,
        },
        warning_selected = {
          bg = colors.dark_grey,
          fg = colors.yellow,
          bold = false,
        },
        warning_diagnostic = {
          bg = colors.bg_dark,
          fg = colors.yellow,
        },
        warning_diagnostic_visible = {
          bg = colors.bg_dark,
          fg = colors.yellow,
        },
        warning_diagnostic_selected = {
          bg = colors.dark_grey,
          fg = colors.yellow,
          bold = false,
        },
      },
    })

    -- Keymaps for cycling between buffers
    vim.keymap.set("n", "<S-l>", ":BufferLineCycleNext<CR>", { silent = true, desc = "Next buffer" })
    vim.keymap.set("n", "<S-h>", ":BufferLineCyclePrev<CR>", { silent = true, desc = "Previous buffer" })

    -- Close buffer with leader+c
    vim.keymap.set("n", "<leader>c", ":bdelete<CR>", { silent = true, desc = "Close buffer" })
  end,
}
