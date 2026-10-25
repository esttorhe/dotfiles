-- ABOUTME: Markdown setup: render-markdown.nvim is the single renderer, and
-- ABOUTME: markdownlint-cli2 is pointed at an explicit config for lint and fix.

-- markdownlint-cli2 only looks for config files in the process working
-- directory; it does not walk up from the file being linted. Resolving the
-- path here lets a project's own config win, with a prose-friendly global
-- config as the fallback instead of the stock 80-column defaults.
local global_config = (vim.env.XDG_CONFIG_HOME or vim.env.HOME .. "/.config")
  .. "/markdownlint/markdownlint-cli2.yaml"

local project_configs = {
  ".markdownlint-cli2.jsonc",
  ".markdownlint-cli2.yaml",
  ".markdownlint-cli2.cjs",
  ".markdownlint-cli2.mjs",
  ".markdownlint.jsonc",
  ".markdownlint.json",
  ".markdownlint.yaml",
  ".markdownlint.yml",
  ".markdownlint.cjs",
  ".markdownlint.mjs",
}

local function markdownlint_config(path)
  path = (path and path ~= "") and path or vim.fn.getcwd()
  local found = vim.fs.find(project_configs, { path = path, upward = true, type = "file" })[1]
  return found or global_config
end

return {
  -- LazyVim's markdown extra strips render-markdown down to `heading.icons = {}`
  -- and `checkbox.enabled = false`, which leaves raw `#` markers and unrendered
  -- task lists. Restore the plugin's own defaults for both.
  {
    "MeanderingProgrammer/render-markdown.nvim",
    opts = {
      heading = {
        icons = { "\u{f0ca1} ", "\u{f0ca3} ", "\u{f0ca5} ", "\u{f0ca7} ", "\u{f0ca9} ", "\u{f0cab} " },
      },
      checkbox = {
        enabled = true,
      },
    },
  },
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters = {
        ["markdownlint-cli2"] = {
          args = {
            "--config",
            function()
              return markdownlint_config(vim.api.nvim_buf_get_name(0))
            end,
            "-",
          },
        },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters = {
        ["markdownlint-cli2"] = {
          prepend_args = function(_, ctx)
            return { "--config", markdownlint_config(ctx.filename) }
          end,
        },
      },
    },
  },
}
