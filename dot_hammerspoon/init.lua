-- ABOUTME: Hammerspoon entry point with global hotkeys.
-- ABOUTME: Cmd+Shift+Z opens a floating quick-add panel for Multica issues; Option+Tab switches windows and tabs.

-- Enables the `hs` command-line tool (e.g. `hs -c 'hs.reload()'`).
require("hs.ipc")

local multicaQuickAdd = require("multica_quick_add")
local tabSwitcher = require("tab_switcher")

hs.hotkey.bind({ "cmd", "shift" }, "z", multicaQuickAdd.toggle)
hs.hotkey.bind({ "alt" }, "tab", tabSwitcher.toggle)
