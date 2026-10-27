-- ABOUTME: Rex configuration mirroring the tmux setup (Ctrl-X prefix, vi-style panes).
-- ABOUTME: Keys are prefix sequences like tmux; resize uses an exclusive key mode.

local P = "ctrl+x>"

-- Press the prefix twice to send it to the program (nvim, emacs-style shells)
rex.bind(P .. "ctrl+x", "pane.send_key", { key = "ctrl+x" })

-- Config
rex.bind(P .. "shift+r", "client.config.reload")

-- Tabs (tmux windows)
rex.bind(P .. "t", "client.tab.new")
rex.bind(P .. "n", "client.tab.next")
rex.bind(P .. "p", "client.tab.previous")
rex.bind(P .. "ctrl+l", "client.tab.next")
rex.bind(P .. "ctrl+h", "client.tab.previous")
rex.bind(P .. "shift+q", "client.tab.close")
rex.bind(P .. ",", "client.tab.rename")
for i = 1, 9 do rex.bind(P .. tostring(i), "client.tab.goto", { index = i }) end

-- Panes
rex.bind(P .. "e", "pane.split", { direction = "right" })
rex.bind(P .. "shift+e", "pane.split", { direction = "down" })
rex.bind(P .. "h", "pane.focus", { direction = "left" })
rex.bind(P .. "k", "pane.focus", { direction = "up" })
rex.bind(P .. "l", "pane.focus", { direction = "right" })
rex.bind(P .. "x", "pane.close")
rex.bind(P .. "shift+w", "pane.close")
rex.bind(P .. "z", "pane.zoom")
rex.bind("alt+left", "pane.focus", { direction = "left" })
rex.bind("alt+right", "pane.focus", { direction = "right" })
rex.bind("alt+up", "pane.focus", { direction = "up" })
rex.bind("alt+down", "pane.focus", { direction = "down" })

-- Sessions (sesh picker in tmux)
rex.bind(P .. "j", "session.switch")
rex.bind(P .. "s", "session.switch")

-- Resize mode: prefix + H/J/K/L enters, hjkl resize, Escape leaves
rex.mode("resize", { exclusive = true })
rex.bind(P .. "shift+h", "client.mode.enter", { name = "resize" })
rex.bind("resize/h", "pane.resize", { direction = "left", amount = 5 })
rex.bind("resize/j", "pane.resize", { direction = "down", amount = 5 })
rex.bind("resize/k", "pane.resize", { direction = "up", amount = 5 })
rex.bind("resize/l", "pane.resize", { direction = "right", amount = 5 })
rex.bind("resize/=", "pane.balance")
rex.bind("resize/enter", "client.mode.exit")

-- Session save/restore with rex-resurrect (prefix C-s / C-r, as in tmux-resurrect).
-- launchd also saves every five minutes and restores once after Rex starts.
local home = os.getenv("HOME")

local function resurrect(command)
  local r, err = rex.exec({ home .. "/.local/bin/rex-resurrect", command }, {
    env = { PATH = home .. "/.local/bin:/opt/homebrew/bin:/usr/bin:/bin" },
    timeout = 120,
  })
  if not r then error(err, 0) end
  if r.code ~= 0 then error("rex-resurrect " .. command .. ": " .. r.stderr, 0) end
  rex.log("rex-resurrect " .. command .. ": " .. r.stdout)
  return rex.json.decode(r.stdout)
end

rex.action{
  name = "resurrect_save",
  title = "Save Sessions (rex-resurrect)",
  category = "Sessions",
  run = function() return resurrect("save") end,
}

rex.action{
  name = "resurrect_restore",
  title = "Restore Sessions (rex-resurrect)",
  category = "Sessions",
  run = function() return resurrect("restore") end,
}

rex.bind(P .. "ctrl+s", "resurrect_save")
rex.bind(P .. "ctrl+r", "resurrect_restore")

-- Floating panes (tmux display-popup). Rex calls them floating layers; a layer
-- closes on its own when its program exits.
local SHELL_FLAVOR = "com.superlogical.terminal.shell"
local TERMINAL = "com.superlogical.terminal"
-- Floating layers must cover the whole window: Rex draws a layer that covers
-- only part of it as an empty overlay.
local POPUP_BOUNDS = { 0, 0, 1, 1 }

-- The focused pane's directory, from the file:// URL its shell reports.
local function focused_cwd()
  local result = rex.block.call(TERMINAL, "pwd", {})
  local url = result and result.pwd or ""
  local path = url:gsub("^file://[^/]*", "")
  return (path:gsub("%%(%x%x)", function(hex) return string.char(tonumber(hex, 16)) end))
end

-- A popup is a pane opened beside the focused one and zoomed to fill the tab.
-- Floating layers can't be used: Rex shows a program's default background in
-- them as see-through, so the pane underneath bleeds through. Quitting the
-- program closes its pane, and the tab's layout comes back.
local function popup(ctx, command)
  local options = { cwd = focused_cwd() }
  if command then options.command = command end
  local created, err = rex.session.new_split{
    anchor_id = ctx.block_id,
    direction = "horizontal",
    side = "after",
    focus = true,
    layout = rex.layout.block{ flavor = SHELL_FLAVOR, options = options },
  }
  if err ~= nil then error(err, 0) end
  local _, zoom_err = rex.session.zoom_block{ block_id = created.block_ids[1], zoom = true }
  if zoom_err ~= nil then error(zoom_err, 0) end
end

rex.action{
  name = "popup_lazygit",
  title = "Lazygit (floating)",
  category = "Panes",
  run = function(ctx) popup(ctx, { "lazygit" }) end,
}

rex.action{
  name = "popup_shell",
  title = "Scratch Shell (floating)",
  category = "Panes",
  run = function(ctx) popup(ctx, nil) end,
}

-- Float the focused pane, or put a floating one back into the tiled layout,
-- beside the last tiled pane.
rex.action{
  name = "toggle_float",
  title = "Float or Dock Pane",
  category = "Panes",
  run = function(ctx)
    local view, err = rex.session.view{}
    if err ~= nil then error(err, 0) end
    for _, window in ipairs(view.windows) do
      local tiled, home
      for _, layer in ipairs(window.layers) do
        if layer.kind == "tiled" then tiled = layer end
        for _, block in ipairs(layer.blocks) do
          if block.block_id == ctx.block_id then home = layer end
        end
      end
      if home and home.kind == "tiled" then
        -- Floating a tab's only pane leaves it without a tiled layout, which Rex
        -- can't draw or dock back into.
        if #home.blocks < 2 then error("can't float the only pane in this tab", 0) end
        local _, e = rex.session.float_block{ block_id = ctx.block_id, bounds = POPUP_BOUNDS }
        if e ~= nil then error(e, 0) end
        return
      elseif home then
        if not tiled or #tiled.blocks == 0 then error("no tiled pane to dock beside", 0) end
        local _, e = rex.session.move_block{
          block_id = ctx.block_id,
          anchor_block_id = tiled.blocks[#tiled.blocks].block_id,
          direction = "horizontal",
          side = "after",
        }
        if e ~= nil then error(e, 0) end
        return
      end
    end
    error("the focused pane isn't in this session", 0)
  end,
}

rex.bind(P .. "g", "popup_lazygit")
rex.bind(P .. "f", "popup_shell")
rex.bind(P .. "shift+f", "toggle_float")

-- rex-opener (installed by chezmoi from .chezmoiexternal.toml): open a URL or file
-- found in the focused pane's output. It needs Python 3.10+, so Homebrew comes
-- before mise, whose default python3 is older; ~/.local/bin holds the rex CLI.
dofile(home .. "/.config/rex/plugins/rex-opener/init.lua")({
  path = home .. "/.local/bin:/opt/homebrew/bin:" .. home
    .. "/.local/share/mise/shims:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
})
-- rex.bind(P .. "o", "rex_opener_open")  -- unbound while the picker issue is debugged
