-- ABOUTME: Comment.nvim for toggling code comments with gcc/gc/gbc/gb
-- ABOUTME: Supports line and block comments with operator-pending mappings
return {
  "numToStr/Comment.nvim",
  lazy = false,
  config = function()
    require("Comment").setup({
      -- Add a space between comment and the line
      padding = true,
      -- Should key mappings be created
      mappings = {
        -- Operator-pending mapping
        -- Includes `gcc`, `gcb`, `gc[count]{motion}` and `gb[count]{motion}`
        basic = true,
        -- Extra mapping
        -- Includes `gco`, `gcO`, `gcA`
        extra = true,
      },
      -- LHS of toggle mappings in NORMAL mode
      toggler = {
        line = 'gcc',  -- Line-comment toggle keymap
        block = 'gbc', -- Block-comment toggle keymap
      },
      -- LHS of operator-pending mappings in NORMAL and VISUAL mode
      opleader = {
        line = 'gc',   -- Line-comment keymap
        block = 'gb',  -- Block-comment keymap
      },
    })
  end,
}
