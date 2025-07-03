-- lua/plugins/copilot.lua
return {
  "github/copilot.vim",
  lazy = false, -- Load immediately rather than on keystroke
  config = function()
    -- Basic configuration
    vim.g.copilot_no_tab_map = true -- Disable the tab mapping
    vim.g.copilot_assume_mapped = true
    vim.g.copilot_tab_fallback = ""

    -- Filetypes configuration - enable/disable for specific filetypes
    vim.g.copilot_filetypes = {
      ["*"] = true, -- Enable for all filetypes by default
      ["markdown"] = false, -- Disable for markdown
      ["text"] = false, -- Disable for text files
      ["help"] = false, -- Disable for help files
      ["gitcommit"] = false, -- Disable for git commit messages
      ["TelescopePrompt"] = false,
      ["DressingInput"] = false,
    }

    -- Custom keymappings for accepting suggestions
    vim.keymap.set("i", "<C-j>", 'copilot#Accept("<CR>")', {
      silent = true,
      expr = true,
      script = true,
      replace_keycodes = false,
    })

    -- Additional keymappings for navigating suggestions
    vim.keymap.set("i", "<C-l>", 'copilot#Accept("<Right>")', {
      silent = true,
      expr = true,
      script = true,
      replace_keycodes = false,
    })
    vim.keymap.set("i", "<M-]>", "<Plug>(copilot-next)", { silent = true })
    vim.keymap.set("i", "<M-[>", "<Plug>(copilot-previous)", { silent = true })
    vim.keymap.set("i", "<M-\\>", "<Plug>(copilot-suggest)", { silent = true })
    vim.keymap.set("i", "<C-\\>", "<Cmd>Copilot panel<CR>", { silent = true })

    -- Setup autocommands for Copilot
    vim.api.nvim_create_augroup("copilot_settings", { clear = true })

    -- Auto-enable when entering insert mode
    vim.api.nvim_create_autocmd("InsertEnter", {
      group = "copilot_settings",
      callback = function()
        if vim.g.copilot_enabled == false then
          vim.cmd("Copilot enable")
        end
      end,
    })

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
