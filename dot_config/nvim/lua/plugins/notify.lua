return {
  "rcarriga/nvim-notify",
  keys = {
    {
      "<leader>und",
      function()
        require("notify").dismiss({ silent = true, pending = true })
      end,
      desc = "Delete all Notifications",
    },
    {
      "<leader>un",
      function()
        require("telescope").extensions.notify.notify({})
      end,
      desc = "Notification History",
    },
  },
  opts = {
    top_down = false,
    timeout = 3000,
    max_height = function()
      return math.floor(vim.o.lines * 0.75)
    end,
    max_width = function()
      return math.floor(vim.o.columns * 0.75)
    end,
    render = "minimal",
  },
  init = function()
    -- when noice is not enabled, install notify on VeryLazy
    local Util = require("lazyvim.util")
    if not Util.has("noice.nvim") then
      Util.on_very_lazy(function()
        vim.notify = require("notify")
      end)
    end
  end,
}
