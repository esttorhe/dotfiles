-- ABOUTME: Standing desk tracker menu bar item: live stand/sit timer, today's stats, period stats and controls.
-- ABOUTME: Persists to ~/.local/share/standing-desk/state.json, auto-pauses when idle, reminds via HUD and notifications.

local core = require("standing_desk_core")

local M = {}

local DATA_DIR = os.getenv("HOME") .. "/.local/share/standing-desk"
local STATE_PATH = DATA_DIR .. "/state.json"
-- Written by the Raycast extension's "Export Standing Desk Sessions" command; imported once, then renamed.
local RAYCAST_EXPORT_PATH = DATA_DIR .. "/raycast-export.json"
local PREFS_PATH = DATA_DIR .. "/prefs.json"
local CHEZMOI_BIN = os.getenv("HOME") .. "/.local/share/mise/shims/chezmoi"
local SETTINGS_WIDTH, SETTINGS_HEIGHT = 460, 470

local TITLE_REFRESH_SECONDS = 1
local CHECK_INTERVAL_SECONDS = 30

local GREEN = { hex = "#22c55e" }
local BLUE = { hex = "#3b82f6" }
local MUTED = { white = 0.5, alpha = 1 }

-- Settings are edited from the menu's Settings… window; missing keys fall back to core.DEFAULT_PREFS.
M.prefs = core.sanitizePrefs({})

local function nowMs()
	return math.floor(hs.timer.secondsSinceEpoch() * 1000)
end

local function load()
	local file = io.open(STATE_PATH, "r")
	if not file then
		return core.emptyData()
	end
	local raw = file:read("*a")
	file:close()

	local ok, decoded = pcall(hs.json.decode, raw)
	if not ok or type(decoded) ~= "table" then
		-- Keep the unreadable file around rather than silently overwriting someone's history.
		os.rename(STATE_PATH, STATE_PATH .. ".corrupt-" .. os.time())
		hs.alert.show("Standing Desk: state file was unreadable, starting fresh")
		return core.emptyData()
	end
	decoded.sessions = decoded.sessions or {}
	return decoded
end

-- Writes to a temp file and renames it, so a crash mid-write never leaves a truncated state file.
local function save()
	hs.fs.mkdir(DATA_DIR)
	local tmp = STATE_PATH .. ".tmp"
	local file = assert(io.open(tmp, "w"))
	file:write(hs.json.encode(M.data, true))
	file:close()
	assert(os.rename(tmp, STATE_PATH))
end

local function label(state)
	if state == "standing" then
		return "Standing"
	elseif state == "sitting" then
		return "Sitting"
	end
	return "Not Tracking"
end

local function stateColor(state)
	return state == "standing" and GREEN or BLUE
end

-- A menu row with a coloured arrow, a title and a muted subtitle, approximating Raycast's list rows.
local function row(symbol, color, title, subtitle)
	local text = hs.styledtext.new(symbol .. "  ", { color = color })
		.. hs.styledtext.new(title)
	if subtitle then
		text = text .. hs.styledtext.new("  " .. subtitle, { color = MUTED })
	end
	return text
end

local function header(title)
	return { title = title, disabled = true }
end

local function refreshTitle()
	if M.menubar then
		M.menubar:setTitle(core.menuTitle(M.data, nowMs()))
	end
end

local function remind(message)
	local style = M.prefs.notificationStyle
	if style ~= "notification" then
		hs.alert.show(message, 4)
	end
	if style ~= "hud" then
		hs.notify.new({ title = "Standing Desk", informativeText = message }):send()
	end
end

local function mutate(fn)
	local result = fn(M.data, nowMs())
	save()
	refreshTitle()
	return result
end

function M.startState(state)
	mutate(function(data, now)
		core.start(data, state, now)
	end)
	hs.alert.show("Started " .. label(state))
end

function M.toggle()
	local state = mutate(core.toggle)
	hs.alert.show("Switched to " .. label(state))
end

function M.stop()
	local session = mutate(core.stop)
	hs.alert.show(session and ("Stopped tracking, recorded " .. core.formatDuration(session.duration)) or "Stopped tracking")
end

function M.discard()
	mutate(function(data)
		core.discard(data)
	end)
	hs.alert.show("Discarded the current session")
end

local function importRaycastExport()
	if not hs.fs.attributes(RAYCAST_EXPORT_PATH) then
		return
	end
	local file = io.open(RAYCAST_EXPORT_PATH, "r")
	local raw = file:read("*a")
	file:close()

	local ok, export = pcall(hs.json.decode, raw)
	if not ok or type(export) ~= "table" then
		hs.alert.show("Standing Desk: could not read the Raycast export")
		os.rename(RAYCAST_EXPORT_PATH, RAYCAST_EXPORT_PATH .. ".unreadable")
		return
	end

	local added = mutate(function(data)
		return core.importRaycast(data, export)
	end)
	os.rename(RAYCAST_EXPORT_PATH, DATA_DIR .. "/raycast-export.imported-" .. os.time() .. ".json")
	hs.alert.show(string.format("Standing Desk: imported %d sessions from Raycast", added))
end

local function check()
	importRaycastExport()

	local now = nowMs()
	if core.autoPause(M.data, hs.host.idleTime(), M.prefs, now) then
		save()
		refreshTitle()
		return
	end

	local reminder = core.reminder(M.data, M.prefs, now)
	if reminder then
		core.markNotified(M.data, reminder, now)
		save()
		remind(reminder.message)
	end
end

local function loadPrefs()
	local file = io.open(PREFS_PATH, "r")
	if not file then
		return core.sanitizePrefs({})
	end
	local raw = file:read("*a")
	file:close()

	local ok, decoded = pcall(hs.json.decode, raw)
	local prefs, err = core.sanitizePrefs(ok and type(decoded) == "table" and decoded or {})
	if not prefs then
		hs.alert.show("Standing Desk: " .. err .. ", using defaults")
		return core.sanitizePrefs({})
	end
	return prefs
end

local function savePrefs(prefs)
	hs.fs.mkdir(DATA_DIR)
	local tmp = PREFS_PATH .. ".tmp"
	local file = assert(io.open(tmp, "w"))
	file:write(hs.json.encode(prefs, true))
	file:close()
	assert(os.rename(tmp, PREFS_PATH))

	-- prefs.json is managed by chezmoi so settings follow to other machines; copy the edit back
	-- into the chezmoi source so it is not overwritten by the next `chezmoi apply`.
	hs.task.new(CHEZMOI_BIN, function(exitCode, _, stderr)
		if exitCode ~= 0 then
			hs.alert.show("Standing Desk: chezmoi re-add failed, see console")
			print("standing_desk: chezmoi re-add failed: " .. tostring(stderr))
		end
	end, { "re-add", PREFS_PATH }):start()
end

local function closeSettings()
	if M.settingsWindow then
		M.settingsWindow:delete()
		M.settingsWindow = nil
	end
end

local function sendToSettings(fn, payload)
	if M.settingsWindow then
		M.settingsWindow:evaluateJavaScript(string.format("%s(%s)", fn, hs.json.encode(payload)))
	end
end

function M.openSettings()
	if M.settingsWindow then
		M.settingsWindow:show():bringToFront(true)
		return
	end

	local controller = hs.webview.usercontent.new("standingDesk")
	controller:setCallback(function(message)
		local body = message.body
		if body.action == "ready" then
			sendToSettings("loadPrefs", M.prefs)
		elseif body.action == "save" then
			local prefs, err = core.sanitizePrefs(body.prefs)
			if not prefs then
				sendToSettings("showError", { message = err })
				return
			end
			savePrefs(prefs)
			M.prefs = prefs
			closeSettings()
			hs.alert.show("Standing Desk settings saved")
		elseif body.action == "cancel" then
			closeSettings()
		end
	end)

	local screen = hs.screen.mainScreen():frame()
	local rect = {
		x = screen.x + (screen.w - SETTINGS_WIDTH) / 2,
		y = screen.y + (screen.h - SETTINGS_HEIGHT) / 3,
		w = SETTINGS_WIDTH,
		h = SETTINGS_HEIGHT,
	}
	M.settingsWindow = hs.webview.new(rect, {}, controller)
		:windowTitle("Standing Desk Settings")
		:windowStyle({ "titled", "closable" })
		:level(hs.drawing.windowLevels.floating)
		:allowTextEntry(true)
		:deleteOnClose(true)
		:windowCallback(function(action)
			if action == "closing" then
				M.settingsWindow = nil
			end
		end)
		:html(io.open(hs.configdir .. "/standing_desk_settings.html"):read("*a"))
		:show()
		:bringToFront(true)
end

local PERIODS = {
	{ key = "day", label = "Today" },
	{ key = "week", label = "This Week" },
	{ key = "month", label = "This Month" },
}

local function statsMenu(period, now)
	local s = core.calculateStats(core.sessionsForPeriod(core.withCurrent(M.data, now), period, now))
	local bar = 20
	local fmt = core.formatDuration
	return {
		header("Overview"),
		{ title = row("◷", MUTED, "Total Time", fmt(s.totalTime)) },
		{ title = row("↑", GREEN, "Standing Time", string.format("%s (%.1f%%)", fmt(s.totalStanding), s.standingPercentage)) },
		{ title = row("↓", BLUE, "Sitting Time", string.format("%s (%.1f%%)", fmt(s.totalSitting), s.sittingPercentage)) },
		{ title = "-" },
		header("Visual Breakdown"),
		{ title = row("↑", GREEN, "Standing", core.progressBar(s.standingPercentage, bar) .. string.format(" %.1f%%", s.standingPercentage)) },
		{ title = row("↓", BLUE, "Sitting", core.progressBar(s.sittingPercentage, bar) .. string.format(" %.1f%%", s.sittingPercentage)) },
		{ title = "-" },
		header("Session Statistics"),
		{ title = row("≡", MUTED, "Total Sessions", s.sessionCount .. " sessions") },
		{ title = row("◷", MUTED, "Average Session", fmt(s.averageSessionDuration)) },
		{ title = row("▲", { hex = "#f59e0b" }, "Longest Session", fmt(s.longestSession)) },
		{ title = row("▼", { hex = "#8b5cf6" }, "Shortest Session", fmt(s.shortestSession)) },
	}
end

local function buildMenu()
	local now = nowMs()
	local data = M.data
	local state = data.current and data.current.state
	local standing, sitting = core.todayTotals(data, now)

	local menu = {
		header("Current Status"),
		{
			title = state
					and row(core.stateSymbol(state), stateColor(state), label(state), "Elapsed: " .. core.formatDuration(core.elapsedSeconds(data, now)))
				or row("○", MUTED, "Not Tracking", "Start tracking"),
			disabled = true,
		},
		{ title = "-" },
		header("Today's Stats"),
		{ title = row("↑", GREEN, "Standing", core.formatDuration(standing)), disabled = true },
		{ title = row("↓", BLUE, "Sitting", core.formatDuration(sitting)), disabled = true },
		{ title = row("◷", MUTED, "Total", core.formatDuration(standing + sitting)), disabled = true },
		{ title = "-" },
	}

	if state then
		local nextState = state == "standing" and "sitting" or "standing"
		menu[#menu + 1] = {
			title = row(core.stateSymbol(nextState), stateColor(nextState), "Switch to " .. label(nextState)),
			fn = M.toggle,
		}
		menu[#menu + 1] = { title = row("◉", MUTED, "Stop Tracking", "Record this session and stop"), fn = M.stop }
		menu[#menu + 1] = { title = row("✕", MUTED, "Discard Current Session", "Stop without recording"), fn = M.discard }
	else
		menu[#menu + 1] = { title = row("↑", GREEN, "Start Standing"), fn = function() M.startState("standing") end }
		menu[#menu + 1] = { title = row("↓", BLUE, "Start Sitting"), fn = function() M.startState("sitting") end }
	end

	menu[#menu + 1] = { title = "-" }
	for _, p in ipairs(PERIODS) do
		menu[#menu + 1] = { title = "Stats: " .. p.label, menu = statsMenu(p.key, now) }
	end
	menu[#menu + 1] = { title = "-" }
	menu[#menu + 1] = { title = "Settings…", fn = M.openSettings }
	return menu
end

-- Exposed so the menu can be built and inspected from the `hs` CLI.
M.buildMenu = buildMenu

function M.start()
	M.prefs = loadPrefs()
	M.data = load()
	M.menubar = hs.menubar.new(true, "standingDesk")
	M.menubar:setMenu(buildMenu)
	refreshTitle()

	-- Kept on the module table so they are not garbage collected.
	M.titleTimer = hs.timer.doEvery(TITLE_REFRESH_SECONDS, refreshTitle)
	M.checkTimer = hs.timer.doEvery(CHECK_INTERVAL_SECONDS, check)
	check()
	return M
end

return M
