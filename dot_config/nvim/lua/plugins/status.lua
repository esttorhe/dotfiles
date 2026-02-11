-- ABOUTME: Lualine status line with bubbles theme (Tokyo Night Moon colors)
-- ABOUTME: Shows mode, git info, diagnostics, whitespace issues, and file info

return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    -- Conditions for conditional component rendering
    local conditions = {
      buffer_not_empty = function()
        return vim.fn.empty(vim.fn.expand("%:t")) ~= 1
      end,
      hide_in_width = function()
        return vim.fn.winwidth(0) > 80
      end,
      check_git_workspace = function()
        local filepath = vim.fn.expand("%:p:h")
        local gitdir = vim.fn.finddir(".git", filepath .. ";")
        return gitdir and #gitdir > 0 and #gitdir < #filepath
      end,
    }

    -- Tokyo Night Moon colors for bubbles theme
    local colors = {
      blue = "#82aaff",
      cyan = "#86e1fc",
      black = "#1e2030",
      white = "#c8d3f5",
      red = "#ff757f",
      violet = "#fca7ea",
      grey = "#222436",
      green = "#c3e88d",
      yellow = "#ffc777",
      orange = "#ff966c",
      magenta = "#c099ff",
      teal = "#4fd6be",
    }

    local bubbles_theme = {
      normal = {
        a = { fg = colors.black, bg = colors.violet, gui = "bold" },
        b = { fg = colors.white, bg = colors.grey },
        c = { fg = colors.white },
      },
      insert = {
        a = { fg = colors.black, bg = colors.blue, gui = "bold" },
      },
      visual = {
        a = { fg = colors.black, bg = colors.cyan, gui = "bold" },
      },
      replace = {
        a = { fg = colors.black, bg = colors.red, gui = "bold" },
      },
      command = {
        a = { fg = colors.black, bg = colors.yellow, gui = "bold" },
      },
      inactive = {
        a = { fg = colors.white, bg = colors.black },
        b = { fg = colors.white, bg = colors.black },
        c = { fg = colors.white },
      },
    }

    -- Custom Copilot indicator
    local function copilot_indicator()
      if vim.g.loaded_copilot == nil then
        return ""
      end
      if vim.g.copilot_enabled == false then
        return ""
      end
      local enabled = vim.b.copilot_enabled
      if enabled == nil then
        enabled = vim.g.copilot_enabled
      end
      if enabled then
        return " "
      else
        return ""
      end
    end

    require("lualine").setup({
      options = {
        theme = bubbles_theme,
        component_separators = "",
        section_separators = { left = "\u{e0b4}", right = "\u{e0b6}" },
        disabled_filetypes = {
          statusline = {},
          winbar = {},
        },
        globalstatus = true,
      },
      sections = {
        lualine_a = {
          { "mode", separator = { right = "\u{e0b4}" }, right_padding = 2 },
        },
        lualine_b = {
          {
            "branch",
            icon = "\u{e0a0}",
            separator = { right = "\u{e0b4}" },
            color = { fg = colors.black, bg = colors.teal, gui = "bold" },
            cond = conditions.check_git_workspace,
          },
          {
            "filename",
            cond = conditions.buffer_not_empty,
            file_status = true,
            path = 1,
            symbols = {
              modified = "●",
              readonly = "\u{f023}",
              unnamed = "\u{f15b}",
            },
          },
        },
        lualine_c = {
          {
            copilot_indicator,
            color = { fg = colors.teal },
          },
        },
        lualine_x = {
          {
            -- Git added lines
            function()
              local gitsigns = vim.b.gitsigns_status_dict
              if gitsigns and gitsigns.added and gitsigns.added > 0 then
                return "\u{f067} " .. gitsigns.added
              end
              return ""
            end,
            separator = { left = "\u{e0b6}" },
            color = { fg = colors.black, bg = colors.green, gui = "bold" },
            cond = conditions.check_git_workspace,
          },
          {
            -- Git modified lines
            function()
              local gitsigns = vim.b.gitsigns_status_dict
              if gitsigns and gitsigns.changed and gitsigns.changed > 0 then
                return "\u{f459} " .. gitsigns.changed
              end
              return ""
            end,
            separator = { left = "\u{e0b6}" },
            color = { fg = colors.black, bg = colors.violet, gui = "bold" },
            cond = conditions.check_git_workspace,
          },
          {
            -- Git deleted lines
            function()
              local gitsigns = vim.b.gitsigns_status_dict
              if gitsigns and gitsigns.removed and gitsigns.removed > 0 then
                return "\u{f458} " .. gitsigns.removed
              end
              return ""
            end,
            separator = { left = "\u{e0b6}" },
            color = { fg = colors.black, bg = colors.red, gui = "bold" },
            cond = conditions.check_git_workspace,
          },
          {
            -- LSP Errors
            function()
              local errors = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR })
              if errors > 0 then
                return "\u{f06a} " .. errors
              end
              return ""
            end,
            separator = { left = "\u{e0b6}" },
            color = { fg = colors.black, bg = colors.red, gui = "bold" },
            cond = function()
              return #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.ERROR }) > 0
            end,
          },
          {
            -- LSP Warnings
            function()
              local warnings = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN })
              if warnings > 0 then
                return "\u{f071} " .. warnings
              end
              return ""
            end,
            separator = { left = "\u{e0b6}" },
            color = { fg = colors.black, bg = colors.yellow, gui = "bold" },
            cond = function()
              return #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.WARN }) > 0
            end,
          },
          {
            -- LSP Info
            function()
              local info = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.INFO })
              if info > 0 then
                return "\u{f05a} " .. info
              end
              return ""
            end,
            separator = { left = "\u{e0b6}" },
            color = { fg = colors.black, bg = colors.cyan, gui = "bold" },
            cond = function()
              return #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.INFO }) > 0
            end,
          },
          {
            -- LSP Hints
            function()
              local hints = #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.HINT })
              if hints > 0 then
                return "\u{f0eb} " .. hints
              end
              return ""
            end,
            separator = { left = "\u{e0b6}" },
            color = { fg = colors.black, bg = colors.teal, gui = "bold" },
            cond = function()
              return #vim.diagnostic.get(0, { severity = vim.diagnostic.severity.HINT }) > 0
            end,
          },
          {
            -- Recording status
            function()
              local recording = vim.fn.reg_recording()
              if recording ~= "" then
                return "\u{f111} @" .. recording
              end
              return ""
            end,
            separator = { left = "\u{e0b6}" },
            color = { fg = colors.white, bg = colors.red, gui = "bold" },
          },
          {
            -- Search count
            "searchcount",
            icon = "\u{f002}",
            separator = { left = "\u{e0b6}" },
            color = { fg = colors.black, bg = colors.cyan, gui = "bold" },
            cond = conditions.buffer_not_empty,
          },
          {
            -- Trailing whitespace
            function()
              local trail = vim.fn.search("\\s$", "nw")
              if trail ~= 0 then
                return "\u{f0ad}"
              end
              return ""
            end,
            separator = { left = "\u{e0b6}" },
            color = { fg = colors.black, bg = colors.orange, gui = "bold" },
            cond = conditions.buffer_not_empty,
          },
          {
            -- Mixed indentation
            function()
              local has_tabs = vim.fn.search("^\\t", "nw") ~= 0
              local has_spaces = vim.fn.search("^ ", "nw") ~= 0
              if has_tabs and has_spaces then
                return "\u{f071}"
              end
              return ""
            end,
            separator = { left = "\u{e0b6}" },
            color = { fg = colors.white, bg = colors.red, gui = "bold" },
            cond = conditions.buffer_not_empty,
          },
          {
            function()
              local os_icon = "\u{f179}" -- Apple icon for macOS
              if vim.fn.has("mac") == 1 or vim.fn.has("macunix") == 1 then
                os_icon = "\u{f179}" -- Apple
              elseif vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
                os_icon = "\u{f17a}" -- Windows
              else
                os_icon = "\u{f17c}" -- Linux
              end
              return os_icon
            end,
            separator = { left = "\u{e0b6}" },
            color = { fg = colors.black, bg = colors.magenta, gui = "bold" },
          },
        },
        lualine_y = {
          {
            function()
              local filetype = vim.bo.filetype
              if filetype == "" then
                return ""
              end
              local devicons = require("nvim-web-devicons")
              local icon = devicons.get_icon_by_filetype(filetype)
              return icon or ""
            end,
            separator = { left = "\u{e0b6}" },
            color = { fg = colors.black, bg = colors.orange, gui = "bold" },
          },
          {
            "progress",
            separator = { left = "\u{e0b6}" },
            color = { fg = colors.black, bg = colors.teal, gui = "bold" },
          },
        },
        lualine_z = {
          {
            "location",
            separator = { left = "\u{e0b6}" },
            color = { fg = colors.black, bg = colors.blue, gui = "bold" },
          },
        },
      },
      inactive_sections = {
        lualine_a = { "filename" },
        lualine_b = {},
        lualine_c = {},
        lualine_x = {},
        lualine_y = {},
        lualine_z = { "location" },
      },
      tabline = {},
      extensions = {
        "neo-tree",
        "lazy",
        "trouble",
        "oil",
        "quickfix",
        "fzf",
      },
    })
  end,
}
