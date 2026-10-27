-- ABOUTME: Keyboard-driven switcher over every window and every tab of scriptable browsers/terminals.
-- ABOUTME: Shows an hs.chooser instantly from cached tabs, refreshes them via JXA in the background, and focuses the pick.

local core = require("tab_switcher_core")

local M = {}

local OSASCRIPT = "/usr/bin/osascript"
local QUERY_SCRIPT = hs.configdir .. "/tab_switcher_query.js"
local ACTIVATE_SCRIPT = hs.configdir .. "/tab_switcher_activate.js"

-- Copy of the default filter: visible windows on every Space, sorted most recently focused first.
local windowFilter = hs.window.filter.new()
local chooser = nil
local allChoices = {}
-- Last successful tab query, keyed by bundle ID; shown immediately while a fresh query runs.
local cachedTabs = {}
local queryRunning = false
local iconCache = {}

-- Tasks are kept referenced while running so they are not garbage collected mid-flight.
local runningTasks = {}

-- Sends stdout to a temp file read after exit. Without a streaming callback hs.task stops draining
-- the pipe at 64KB and the child blocks forever, and with one the last chunk can arrive after the
-- termination callback, truncating large outputs such as tab lists.
local function runOsascript(args, callback)
	local outPath = os.tmpname()
	local shellArgs = { "-c", 'out="$1"; shift; exec "$@" > "$out"', "sh", outPath, OSASCRIPT, table.unpack(args) }
	local task
	task = hs.task.new("/bin/sh", function(exitCode, _, stderr)
		runningTasks[task] = nil
		local file = io.open(outPath, "r")
		local stdout = file and file:read("*a") or ""
		if file then
			file:close()
		end
		os.remove(outPath)
		callback(exitCode, stdout, stderr)
	end, shellArgs)
	runningTasks[task] = true
	task:start()
	task:closeInput()
end

local function iconFor(bundleID)
	if bundleID and iconCache[bundleID] == nil then
		iconCache[bundleID] = hs.image.imageFromAppBundle(bundleID) or false
	end
	return iconCache[bundleID] or nil
end

local function focusOrder()
	local order = {}
	for _, window in ipairs(windowFilter:getWindows(hs.window.filter.sortByFocusedLast)) do
		local app = window:application()
		if app then
			table.insert(order, {
				id = window:id(),
				bundleID = app:bundleID(),
				appName = app:name(),
				title = window:title(),
			})
		end
	end
	return order
end

local function applyQuery()
	if chooser then
		chooser:choices(core.filter(allChoices, chooser:query()))
	end
end

local function rebuildChoices()
	allChoices = core.buildChoices(focusOrder(), cachedTabs)
	for _, choice in ipairs(allChoices) do
		choice.image = iconFor(choice.bundleID)
	end
	applyQuery()
end

local function refreshTabs()
	if queryRunning then
		return
	end
	queryRunning = true
	runOsascript({ "-l", "JavaScript", QUERY_SCRIPT }, function(exitCode, stdout, stderr)
		queryRunning = false
		if exitCode ~= 0 then
			print("tab_switcher: tab query failed: " .. stderr)
			return
		end
		local ok, decoded = pcall(hs.json.decode, stdout)
		if not ok or type(decoded) ~= "table" then
			print("tab_switcher: could not decode tab query output: " .. stdout)
			return
		end
		cachedTabs = decoded
		if chooser and chooser:isVisible() then
			-- Keep the highlighted row stable while the list updates under the user.
			local row = chooser:selectedRow()
			rebuildChoices()
			chooser:selectedRow(row)
		end
	end)
end

local function activateTab(choice)
	runOsascript({
		"-l",
		"JavaScript",
		ACTIVATE_SCRIPT,
		choice.bundleID,
		tostring(choice.windowId),
		tostring(choice.tabId),
		tostring(choice.tabIndex),
	}, function(exitCode, _, stderr)
		if exitCode ~= 0 then
			-- The tab or window closed since the last query; landing in the app is the closest match.
			print("tab_switcher: could not activate tab: " .. stderr)
			hs.application.launchOrFocusByBundleID(choice.bundleID)
		end
		refreshTabs()
	end)
end

local function activate(choice)
	if not choice then
		return
	end
	if choice.kind == "tab" then
		activateTab(choice)
		return
	end
	local window = hs.window.get(choice.windowId)
	if window then
		window:focus()
	else
		hs.application.launchOrFocusByBundleID(choice.bundleID)
	end
end

local function ensureChooser()
	if chooser then
		return
	end
	chooser = hs.chooser.new(activate)
	chooser:placeholderText("Switch to window or tab…")
	chooser:searchSubText(true)
	chooser:width(40)
	chooser:queryChangedCallback(function()
		applyQuery()
		chooser:selectedRow(1)
	end)
end

-- Opens the switcher with the second row highlighted, since the first is where you already are.
-- Pressing the hotkey again while it is open moves the highlight down, like ⌘Tab.
function M.toggle()
	ensureChooser()
	if chooser:isVisible() then
		chooser:selectedRow(chooser:selectedRow() + 1)
		return
	end
	chooser:query("")
	rebuildChoices()
	chooser:show()
	if #allChoices > 1 then
		chooser:selectedRow(2)
	end
	refreshTabs()
end

-- Warm the cache so the first open already lists tabs.
refreshTabs()

return M
