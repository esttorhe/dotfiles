-- ABOUTME: Hammerspoon entry point with global hotkeys.
-- ABOUTME: Cmd+Shift+Z opens Multica quick-add, Option+Tab switches windows and tabs, and a menu bar item tracks standing vs sitting.

-- Enables the `hs` command-line tool (e.g. `hs -c 'hs.reload()'`).
require("hs.ipc")

local multicaQuickAdd = require("multica_quick_add")
local tabSwitcher = require("tab_switcher")
local standingDesk = require("standing_desk")

hs.hotkey.bind({ "cmd", "shift" }, "z", multicaQuickAdd.toggle)
hs.hotkey.bind({ "alt" }, "tab", tabSwitcher.toggle)

standingDesk.start()
