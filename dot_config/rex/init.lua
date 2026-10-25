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
rex.bind(P .. "o", "session.switch")
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
