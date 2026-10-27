-- ABOUTME: Keyboard-driven switcher over windows, browser/terminal tabs, Rex tabs and chats, with in-app search rows.
-- ABOUTME: Shows an hs.chooser instantly from cached sources, refreshes them in the background, and focuses the pick.

local core = require("tab_switcher_core")

local M = {}

local OSASCRIPT = "/usr/bin/osascript"
local SQLITE = "/usr/bin/sqlite3"
local REX = os.getenv("HOME") .. "/.local/bin/rex"
local QUERY_SCRIPT = hs.configdir .. "/tab_switcher_query.js"
local ACTIVATE_SCRIPT = hs.configdir .. "/tab_switcher_activate.js"

local MESSAGES_DB = os.getenv("HOME") .. "/Library/Messages/chat.db"
local WHATSAPP_DB = os.getenv("HOME") .. "/Library/Group Containers/group.net.whatsapp.WhatsApp.shared/ChatStorage.sqlite"
local CONTACTS_DIR = os.getenv("HOME") .. "/Library/Application Support/AddressBook"
local REX_BUNDLE_ID = "com.superlogical.rex"
-- How often and how long to wait for an app to come to the front, and for its search field to take
-- focus before typing into it.
local SEARCH_FOCUS_POLL, SEARCH_FOCUS_TIMEOUT = 0.05, 2

local IMESSAGE_SQL = [[
select c.chat_identifier as identifier, c.style, c.display_name as displayName,
  (select group_concat(h.id, '|') from chat_handle_join chj join handle h on h.ROWID = chj.handle_id
   where chj.chat_id = c.ROWID) as members,
  (select max(cmj.message_date) from chat_message_join cmj where cmj.chat_id = c.ROWID) as lastDate
from chat c order by lastDate desc]]

local WHATSAPP_SQL = [[
select ZPARTNERNAME as name, ZCONTACTJID as jid, ZSESSIONTYPE as type
from ZWACHATSESSION where ZREMOVED = 0 order by ZLASTMESSAGEDATE desc]]

local CONTACTS_SQL = [[
select coalesce(nullif(trim(coalesce(r.ZFIRSTNAME, '') || ' ' || coalesce(r.ZLASTNAME, '')), ''), r.ZORGANIZATION) as name,
  p.ZFULLNUMBER as value
from ZABCDPHONENUMBER p join ZABCDRECORD r on r.Z_PK = p.ZOWNER
union all
select coalesce(nullif(trim(coalesce(r.ZFIRSTNAME, '') || ' ' || coalesce(r.ZLASTNAME, '')), ''), r.ZORGANIZATION) as name,
  e.ZADDRESS as value
from ZABCDEMAILADDRESS e join ZABCDRECORD r on r.Z_PK = e.ZOWNER]]

-- Copy of the default filter: visible windows on every Space, sorted most recently focused first.
local windowFilter = hs.window.filter.new()
local chooser = nil
local allChoices = {}
-- Last successful result of each background source; shown immediately while fresh queries run.
local cachedTabs = {}
local cachedRex = {}
local cachedWhatsapp = {}
local cachedImessage = {}
local refreshing = {}
local iconCache = {}
local appSearchTimer = nil
local searchFocusTimer = nil
local installedSearchApps = nil

-- Tasks are kept referenced while running so they are not garbage collected mid-flight.
local runningTasks = {}

-- Sends stdout to a temp file read after exit. Without a streaming callback hs.task stops draining
-- the pipe at 64KB and the child blocks forever, and with one the last chunk can arrive after the
-- termination callback, truncating large outputs such as tab lists and chat databases.
local function runProgram(path, args, callback)
	local outPath = os.tmpname()
	local shellArgs = { "-c", 'out="$1"; shift; exec "$@" > "$out"', "sh", outPath, path, table.unpack(args) }
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

-- Runs a program whose stdout is JSON and hands the decoded value to `callback`, or logs why it could not.
local function runJSON(label, path, args, callback)
	runProgram(path, args, function(exitCode, stdout, stderr)
		if exitCode ~= 0 then
			print(string.format("tab_switcher: %s failed: %s", label, stderr))
			return callback(nil)
		end
		-- sqlite3 -json prints nothing at all for an empty result.
		if stdout:match("^%s*$") then
			return callback({})
		end
		local ok, decoded = pcall(hs.json.decode, stdout)
		if not ok or type(decoded) ~= "table" then
			print(string.format("tab_switcher: could not decode %s output: %s", label, stdout:sub(1, 200)))
			return callback(nil)
		end
		callback(decoded)
	end)
end

local function querySqlite(label, path, sql, callback)
	runJSON(label, SQLITE, { "-json", "-readonly", path, sql }, callback)
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
	if not chooser then
		return
	end
	if not installedSearchApps then
		installedSearchApps = {}
		for bundleID in pairs(core.APP_SEARCH) do
			installedSearchApps[bundleID] = hs.application.pathForBundleID(bundleID) ~= nil
		end
	end
	local query = chooser:query()
	local searches = core.appSearchChoices(query, installedSearchApps)
	local matches = core.filter(allChoices, query)
	if #searches > 0 then
		-- The filter returns the shared list itself for a blank query, so copy before appending.
		matches = { table.unpack(matches) }
		for _, search in ipairs(searches) do
			search.image = iconFor(search.bundleID)
			table.insert(matches, search)
		end
	end
	chooser:choices(matches)
end

local function rebuildChoices()
	local extras = {}
	for _, source in ipairs({ cachedRex, cachedWhatsapp, cachedImessage }) do
		for _, choice in ipairs(source) do
			table.insert(extras, choice)
		end
	end
	allChoices = core.buildChoices(focusOrder(), cachedTabs, extras)
	for _, choice in ipairs(allChoices) do
		choice.image = iconFor(choice.bundleID)
	end
	applyQuery()
end

-- Re-renders an open chooser after a background source updates, keeping the highlighted row stable.
local function sourceUpdated()
	if chooser and chooser:isVisible() then
		local row = chooser:selectedRow()
		rebuildChoices()
		chooser:selectedRow(row)
	end
end

-- Runs `load(done)` unless that source is already refreshing; `done(value)` stores a non-nil value.
local function refreshSource(name, load, store)
	if refreshing[name] then
		return
	end
	refreshing[name] = true
	load(function(value)
		refreshing[name] = false
		if value ~= nil then
			store(value)
			sourceUpdated()
		end
	end)
end

local function loadTabs(done)
	runJSON("tab query", OSASCRIPT, { "-l", "JavaScript", QUERY_SCRIPT }, done)
end

local function loadRex(done)
	runJSON("rex ls", REX, { "--autostart=false", "ls", "--json" }, function(listing)
		if not listing or not listing.sessions or #listing.sessions == 0 then
			return done(listing and {} or nil)
		end
		local sessions, pending = {}, #listing.sessions
		for position, session in ipairs(listing.sessions) do
			runJSON("rex window ls", REX, { "window", "ls", "-s", session.session_id, "--json" }, function(view)
				local windows = {}
				for _, window in ipairs(view and view.windows or {}) do
					table.insert(windows, { id = window.window_id, label = window.label })
				end
				sessions[position] = { id = session.session_id, label = session.label, windows = windows }
				pending = pending - 1
				if pending == 0 then
					done(core.rexChoices(sessions))
				end
			end)
		end
	end)
end

local function loadWhatsapp(done)
	if not hs.fs.attributes(WHATSAPP_DB) then
		return done({})
	end
	querySqlite("whatsapp query", WHATSAPP_DB, WHATSAPP_SQL, function(rows)
		done(rows and core.whatsappChoices(rows))
	end)
end

local function contactDatabases()
	local paths = { CONTACTS_DIR .. "/AddressBook-v22.abcddb" }
	local sources = CONTACTS_DIR .. "/Sources"
	-- hs.fs.dir raises instead of returning nil when macOS denies access to the folder.
	local ok, err = pcall(function()
		for entry in hs.fs.dir(sources) do
			local path = sources .. "/" .. entry .. "/AddressBook-v22.abcddb"
			if entry:sub(1, 1) ~= "." and hs.fs.attributes(path) then
				table.insert(paths, path)
			end
		end
	end)
	if not ok then
		print("tab_switcher: contact names unavailable (grant Hammerspoon Full Disk Access): " .. tostring(err))
	end
	return paths
end

-- Reading Messages and Contacts needs Full Disk Access for Hammerspoon; without it sqlite3 fails
-- and the chats are simply left out.
local function loadImessage(done)
	local databases = contactDatabases()
	local contactRows, pending = {}, #databases
	for _, path in ipairs(databases) do
		querySqlite("contacts query", path, CONTACTS_SQL, function(rows)
			for _, row in ipairs(rows or {}) do
				table.insert(contactRows, row)
			end
			pending = pending - 1
			if pending == 0 then
				querySqlite("messages query", MESSAGES_DB, IMESSAGE_SQL, function(chats)
					done(chats and core.imessageChoices(chats, core.contactIndex(contactRows)))
				end)
			end
		end)
	end
end

local function refreshAll()
	refreshSource("tabs", loadTabs, function(value)
		cachedTabs = value
	end)
	refreshSource("rex", loadRex, function(value)
		cachedRex = value
	end)
	refreshSource("whatsapp", loadWhatsapp, function(value)
		cachedWhatsapp = value
	end)
	refreshSource("imessage", loadImessage, function(value)
		cachedImessage = value
	end)
end

local function activateTab(choice)
	runProgram(OSASCRIPT, {
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
		refreshSource("tabs", loadTabs, function(value)
			cachedTabs = value
		end)
	end)
end

-- Several Rex app clients can be connected; the most recently connected one is the window in use.
local function activateRex(choice)
	runJSON("rex client ls", REX, { "client", "ls", "--json" }, function(listing)
		local newest
		for _, client in ipairs(listing and listing.clients or {}) do
			if client.info and client.info.kind == "app" and (not newest or client.connected_at > newest.connected_at) then
				newest = client
			end
		end
		local args = { "do", "session.select", "session_id=" .. choice.sessionId, "window_id=" .. choice.windowId }
		if newest then
			table.insert(args, 1, "-C")
			table.insert(args, 2, newest.client_id)
		end
		runProgram(REX, args, function(exitCode, _, stderr)
			if exitCode ~= 0 then
				print("tab_switcher: could not select rex tab: " .. stderr)
			end
			hs.application.launchOrFocusByBundleID(REX_BUNDLE_ID)
		end)
	end)
end

local function focusedElement(app)
	return hs.axuielement.applicationElement(app):attributeValue("AXFocusedUIElement")
end

-- Search boxes such as Slack's channel switcher open asynchronously after the menu click, so keys sent
-- right away land in whatever field had focus (a message draft). Typing waits until focus moves off the
-- element that held it before the click, or sits on a search field, and is skipped if neither happens.
local function typeWhenSearchFocused(app, before, query, appName)
	local deadline = hs.timer.secondsSinceEpoch() + SEARCH_FOCUS_TIMEOUT
	if searchFocusTimer then
		searchFocusTimer:stop()
	end
	searchFocusTimer = hs.timer.doEvery(SEARCH_FOCUS_POLL, function()
		local now = focusedElement(app)
		local moved = now and (not before or now ~= before)
		local onSearchField = now and now:attributeValue("AXSubrole") == "AXSearchField"
		if moved or onSearchField then
			searchFocusTimer:stop()
			searchFocusTimer = nil
			hs.eventtap.keyStrokes(query, app)
		elseif hs.timer.secondsSinceEpoch() > deadline then
			searchFocusTimer:stop()
			searchFocusTimer = nil
			print("tab_switcher: " .. appName .. "'s search never took focus; not typing")
		end
	end)
end

-- Calls `fn(app)` once the app is frontmost, since search shortcuts and menus only act on the active app.
local function whenFrontmost(bundleID, appName, fn)
	local deadline = hs.timer.secondsSinceEpoch() + SEARCH_FOCUS_TIMEOUT
	appSearchTimer = hs.timer.doEvery(SEARCH_FOCUS_POLL, function()
		local front = hs.application.frontmostApplication()
		if front and front:bundleID() == bundleID then
			appSearchTimer:stop()
			appSearchTimer = nil
			fn(front)
		elseif hs.timer.secondsSinceEpoch() > deadline then
			appSearchTimer:stop()
			appSearchTimer = nil
			print("tab_switcher: " .. appName .. " never came to the front; not searching")
		end
	end)
end

-- Opens the app's own search through its menu or shortcut and types the query once the search field
-- has focus; picking the result is left to the app.
local function searchApp(choice)
	local search = core.APP_SEARCH[choice.bundleID]
	if appSearchTimer then
		appSearchTimer:stop()
	end
	hs.application.launchOrFocusByBundleID(choice.bundleID)
	whenFrontmost(choice.bundleID, search.appName, function(app)
		if search.electron then
			hs.axuielement.applicationElement(app):setAttributeValue("AXManualAccessibility", true)
		end
		local before = focusedElement(app)
		if search.keys then
			hs.eventtap.keyStroke(search.keys.mods, search.keys.key, 0, app)
		elseif not app:selectMenuItem(search.menu) then
			print("tab_switcher: could not open " .. search.appName .. "'s search")
			return
		end
		typeWhenSearchFocused(app, before, choice.query, search.appName)
	end)
end

local function activate(choice)
	if not choice then
		return
	end
	if choice.kind == "tab" then
		activateTab(choice)
	elseif choice.kind == "rex" then
		activateRex(choice)
	elseif choice.kind == "url" then
		hs.urlevent.openURL(choice.url)
	elseif choice.kind == "appSearch" then
		searchApp(choice)
	else
		local window = hs.window.get(choice.windowId)
		if window then
			window:focus()
		else
			hs.application.launchOrFocusByBundleID(choice.bundleID)
		end
	end
end

local function ensureChooser()
	if chooser then
		return
	end
	chooser = hs.chooser.new(activate)
	chooser:placeholderText("Switch to window, tab or chat…")
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
	refreshAll()
end

-- Warm the caches so the first open already lists tabs and chats.
refreshAll()

return M
