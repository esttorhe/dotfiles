return {
  -- LazyGit integration
  {
    "kdheepak/lazygit.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      vim.keymap.set("n", "<leader>gg", ":LazyGit<CR>", { silent = true, desc = "LazyGit" })
      vim.g.lazygit_floating_window_winblend = 0
      vim.g.lazygit_floating_window_scaling_factor = 0.9
      vim.g.lazygit_floating_window_border_chars = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
      vim.g.lazygit_use_neovim_remote = 1
    end,
  },

  -- Git signs in the gutter
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("gitsigns").setup({
        signs = {
          add = { text = "│" },
          change = { text = "│" },
          delete = { text = "_" },
          topdelete = { text = "‾" },
          changedelete = { text = "~" },
          untracked = { text = "┆" },
        },
        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns

          -- Navigation
          vim.keymap.set("n", "]c", function()
            if vim.wo.diff then
              return "]c"
            end
            vim.schedule(function()
              gs.next_hunk()
            end)
            return "<Ignore>"
          end, { expr = true, buffer = bufnr, desc = "Next Git hunk" })

          vim.keymap.set("n", "[c", function()
            if vim.wo.diff then
              return "[c"
            end
            vim.schedule(function()
              gs.prev_hunk()
            end)
            return "<Ignore>"
          end, { expr = true, buffer = bufnr, desc = "Previous Git hunk" })

          -- Actions
          vim.keymap.set("n", "<leader>gs", gs.stage_hunk, { buffer = bufnr, desc = "Stage hunk" })
          vim.keymap.set("n", "<leader>gr", gs.reset_hunk, { buffer = bufnr, desc = "Reset hunk" })
          vim.keymap.set("n", "<leader>gb", function()
            gs.blame_line({ full = true })
          end, { buffer = bufnr, desc = "Blame line" })
        end,
      })
    end,
  },

  -- Fugitive for Git commands
  {
    "tpope/vim-fugitive",
    config = function()
      vim.keymap.set("n", "<leader>gf", ":Git<CR>", { desc = "Git status (Fugitive)" })
      vim.keymap.set("n", "<leader>gc", ":Git commit<CR>", { desc = "Git commit" })
    end,
  },

  -- DiffView for diffs and merge resolution
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      require("diffview").setup({
        view = {
          default = {
            layout = "diff2_horizontal",
          },
          merge_tool = {
            layout = "diff3_horizontal",
            disable_diagnostics = true,
          },
        },
      })

      vim.keymap.set("n", "<leader>gv", ":DiffviewOpen<CR>", { desc = "DiffviewOpen" })
      vim.keymap.set("n", "<leader>gh", ":DiffviewFileHistory %<CR>", { desc = "Current File History" })
    end,
  },
}
