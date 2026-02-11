-- ABOUTME: blink.cmp completion engine with LSP integration
-- ABOUTME: Works with Copilot Tab pattern (C-space to show, Enter to accept)

return {
  "saghen/blink.cmp",
  dependencies = {
    "rafamadriz/friendly-snippets",
    "onsails/lspkind.nvim",
  },
  version = "1.*",
  opts = function()
    local ok, lspkind = pcall(require, "lspkind")
    return {
      appearance = {
        use_nvim_cmp_as_default = true,
        nerd_font_variant = "mono",
        kind_icons = ok and lspkind.presets.default or {},
      },
      completion = {
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 100,
          update_delay_ms = 50,
          treesitter_highlighting = true,
          window = {
            min_width = 10,
            max_width = 80,
            max_height = 20,
            border = "rounded",
            winblend = 0,
            winhighlight = "Normal:BlinkCmpDoc,FloatBorder:BlinkCmpDocBorder,EndOfBuffer:BlinkCmpDoc",
            scrollbar = true,
          },
        },
        menu = {
          min_width = 15,
          max_height = 10,
          border = "rounded",
          winblend = 8,
          scrollbar = true,
          scrolloff = 2,
          winhighlight = "Normal:BlinkCmpMenu,FloatBorder:BlinkCmpMenuBorder,CursorLine:BlinkCmpMenuSelection,Search:None",
        },
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        providers = {
          lsp = {
            name = "LSP",
            module = "blink.cmp.sources.lsp",
            score_offset = 0,
          },
        },
      },
      signature = {
        enabled = true,
        trigger = {
          enabled = true,
          show_on_insert_on_trigger_character = true,
        },
        window = {
          min_width = 1,
          max_width = 80,
          max_height = 10,
          border = "rounded",
          winblend = 0,
          winhighlight = "Normal:BlinkCmpSignatureHelp,FloatBorder:BlinkCmpSignatureHelpBorder",
          scrollbar = true,
        },
      },
      snippets = {
        expand = function(args)
          vim.snippet.expand(args.body)
        end,
      },
      keymap = {
        preset = "enter",
        ["<CR>"] = { "accept", "fallback" },
        ["<Up>"] = { "select_prev", "fallback" },
        ["<Down>"] = { "select_next", "fallback" },
        ["<S-Tab>"] = { "select_prev", "fallback" },
        ["<C-n>"] = { "show", "show", "show" },
        ["<C-space>"] = { "show", "show", "show" },
        ["<C-e>"] = { "hide", "fallback" },
      },
      fuzzy = { implementation = "prefer_rust_with_warning" },
    }
  end,
  config = function(_, opts)
    require("blink.cmp").setup(opts)
  end,
  opts_extend = { "sources.default" },
}
