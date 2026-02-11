-- ABOUTME: auto-session for project-local session management
-- ABOUTME: Sessions saved in .nvim/ folder, manual save with <leader>ss

return {
  "rmagatti/auto-session",
  lazy = false,
  opts = {
    auto_session_root_dir = vim.fn.getcwd() .. "/.nvim/",
    auto_save = false,
    auto_restore = true,
    auto_create = false,
    suppressed_dirs = { "~/", "~/Downloads", "/" },
    auto_session_use_git_branch = false,
    auto_session_enable_last_session = false,
    log_level = "error",
    bypass_session_save_file_types = { "neo-tree" },
    pre_save_cmds = {
      "Neotree close",
    },
    post_restore_cmds = {
      function()
        vim.defer_fn(function()
          vim.cmd("bufdo e")
        end, 200)
      end,
    },
  },
  config = function(_, opts)
    vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

    require("auto-session").setup(opts)

    -- Keymaps for manual session management
    vim.keymap.set("n", "<leader>ss", "<cmd>AutoSession save<CR>", { desc = "Save session" })
    vim.keymap.set("n", "<leader>sr", "<cmd>AutoSession restore<CR>", { desc = "Restore session" })
    vim.keymap.set("n", "<leader>sd", "<cmd>AutoSession delete<CR>", { desc = "Delete session" })
    vim.keymap.set("n", "<leader>sf", "<cmd>AutoSession search<CR>", { desc = "Search sessions" })

    -- Refresh rainbow brackets after session restore
    vim.api.nvim_create_user_command("RefreshRainbow", function()
      vim.cmd("bufdo e")
    end, { desc = "Refresh rainbow brackets and indent lines" })

    vim.keymap.set("n", "<leader>rr", "<cmd>RefreshRainbow<CR>", { desc = "Refresh rainbow" })
  end,
}
