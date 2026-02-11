-- ABOUTME: GitHub Copilot integration with Tab accept pattern
-- ABOUTME: Tab accepts Copilot suggestions, falls back to blink menu navigation

return {
  "github/copilot.vim",
  lazy = false,
  config = function()
    -- Accept Copilot suggestion with Tab (Arthur's pattern)
    vim.keymap.set("i", "<Tab>", function()
      -- Check if Copilot has a suggestion
      if vim.fn["copilot#GetDisplayedSuggestion"]().text ~= "" then
        return vim.fn["copilot#Accept"]("")
      else
        -- If no Copilot suggestion, check if blink menu is open
        local blink_ok, blink = pcall(require, "blink.cmp")
        if blink_ok and blink.is_visible() then
          blink.select_next()
          return ""
        end

        -- Otherwise, normal tab
        return "\t"
      end
    end, { expr = true, replace_keycodes = false, silent = true })

    -- Enable Copilot for all filetypes
    vim.g.copilot_filetypes = {
      ["*"] = true,
      ["markdown"] = false,
      ["text"] = false,
      ["help"] = false,
      ["gitcommit"] = false,
      ["TelescopePrompt"] = false,
      ["DressingInput"] = false,
    }

    -- Additional keymappings for navigating suggestions
    vim.keymap.set("i", "<M-]>", "<Plug>(copilot-next)", { silent = true, desc = "Copilot next" })
    vim.keymap.set("i", "<M-[>", "<Plug>(copilot-previous)", { silent = true, desc = "Copilot previous" })
    vim.keymap.set("i", "<M-\\>", "<Plug>(copilot-suggest)", { silent = true, desc = "Copilot suggest" })
    vim.keymap.set("i", "<C-\\>", "<Cmd>Copilot panel<CR>", { silent = true, desc = "Copilot panel" })

    -- Create a command to toggle Copilot
    vim.api.nvim_create_user_command("CopilotToggle", function()
      if vim.g.copilot_enabled == true then
        vim.cmd("Copilot disable")
        print("Copilot disabled")
      else
        vim.cmd("Copilot enable")
        print("Copilot enabled")
      end
    end, { nargs = 0 })

    -- Map a key to toggle Copilot
    vim.keymap.set("n", "<leader>cp", "<Cmd>CopilotToggle<CR>", {
      silent = true,
      desc = "Toggle Copilot",
    })
  end,
}
