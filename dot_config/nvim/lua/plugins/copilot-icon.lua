-- lua/plugins/lualine.lua
return {
  "nvim-lualine/lualine.nvim",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
  config = function()
    -- Custom Copilot component for the official plugin
    local function copilot_indicator()
      -- First check if copilot exists and is loaded
      if vim.g.loaded_copilot == nil then
        return ""
      end

      -- Check if copilot is enabled globally
      if vim.g.copilot_enabled == false then
        return ""
      end

      -- Check if copilot is enabled for the current buffer
      local enabled = vim.b.copilot_enabled
      if enabled == nil then
        enabled = vim.g.copilot_enabled
      end

      if enabled then
        return " " -- Icon for enabled state (use any nerd font icon you prefer)
      else
        return "" -- No icon for disabled state
      end
    end

    require("lualine").setup({
      sections = {
        lualine_x = {
          copilot_indicator,
          "encoding",
          "fileformat",
          "filetype",
        },
      },
    })
  end,
}
