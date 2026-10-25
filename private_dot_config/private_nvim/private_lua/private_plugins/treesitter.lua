-- ABOUTME: Treesitter overrides for LazyVim (main branch)
-- ABOUTME: Adds mise TOML predicate and incremental node selection (,v / Tab / S-Tab)

-- Module-level state for node selection stack (vim.g can't store nested tables)
local ts_select = {
  node_stack = {},
}

--- Select a range in visual mode
local function select_range(sr, sc, er, ec)
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_mark(buf, "<", sr + 1, sc, {})
  vim.api.nvim_buf_set_mark(buf, ">", er + 1, ec - 1, {})
  vim.cmd("normal! gv")
end

--- Find the smallest node that fully contains the given range
local function node_covering_range(root, sr, sc, er, ec)
  for child in root:iter_children() do
    local csr, csc, cer, cec = child:range()
    if csr <= sr and csc <= sc and cer >= er and cec >= ec then
      return node_covering_range(child, sr, sc, er, ec) or child
    end
  end
  return nil
end

return {
  "nvim-treesitter/nvim-treesitter",
  init = function()
    require("vim.treesitter.query").add_predicate("is-mise?", function(_, _, bufnr, _)
      local filepath = vim.api.nvim_buf_get_name(tonumber(bufnr) or 0)
      local filename = vim.fn.fnamemodify(filepath, ":t")
      return string.match(filename, ".*mise.*%.toml$") ~= nil
    end, { force = true, all = false })

    -- <leader>v in normal mode: start selecting the treesitter node under cursor
    vim.keymap.set("n", "<leader>v", function()
      local node = vim.treesitter.get_node()
      if not node then
        return
      end
      ts_select.node_stack = {}
      local sr, sc, er, ec = node:range()
      select_range(sr, sc, er, ec)
    end, { desc = "Start treesitter node selection" })

    -- Tab in visual mode: expand selection to parent node
    vim.keymap.set("x", "<Tab>", function()
      -- Exit visual mode to update '< and '> marks
      local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
      vim.api.nvim_feedkeys(esc, "nx", false)

      local vsr = vim.fn.line("'<") - 1
      local vsc = vim.fn.col("'<") - 1
      local ver = vim.fn.line("'>") - 1
      local vec = vim.fn.col("'>")

      -- Find the tree root and the node covering current selection
      local buf = vim.api.nvim_get_current_buf()
      local ok, parser = pcall(vim.treesitter.get_parser, buf)
      if not ok or not parser then
        return
      end
      local tree = parser:parse()[1]
      if not tree then
        return
      end
      local root = tree:root()
      local current = node_covering_range(root, vsr, vsc, ver, vec) or root

      -- Walk up to find a parent with a strictly larger range
      local parent = current:parent()
      while parent do
        local psr, psc, per, pec = parent:range()
        local csr, csc, cer, cec = current:range()
        if psr < csr or psc < csc or per > cer or pec > cec then
          table.insert(ts_select.node_stack, { csr, csc, cer, cec })
          select_range(psr, psc, per, pec)
          return
        end
        parent = parent:parent()
      end
    end, { desc = "Expand treesitter selection" })

    -- Shift+Tab in visual mode: shrink selection back
    vim.keymap.set("x", "<S-Tab>", function()
      if #ts_select.node_stack == 0 then
        vim.cmd("normal! ")
        return
      end
      local prev = table.remove(ts_select.node_stack)
      select_range(prev[1], prev[2], prev[3], prev[4])
    end, { desc = "Shrink treesitter selection" })
  end,
}
