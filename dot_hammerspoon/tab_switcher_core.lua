-- ABOUTME: Pure ordering and filtering logic for the tab switcher, kept free of hs.* so it runs under plain Lua.
-- ABOUTME: Merges focus-ordered windows, scripted browser/terminal tabs, Rex tabs and chats into ranked chooser rows.

local M = {}

local function hostOf(url)
	return url and url:match("^%a[%w+.-]*://([^/?#]+)")
end

local function windowChoice(window)
	return {
		kind = "window",
		text = (window.title and window.title ~= "") and window.title or window.appName,
		subText = window.appName,
		bundleID = window.bundleID,
		windowId = window.id,
	}
end

local function tabChoice(app, bundleID, window, tab)
	local host = hostOf(tab.url)
	return {
		kind = "tab",
		text = (tab.title and tab.title ~= "") and tab.title or (tab.url or app.appName),
		subText = host and (app.appName .. " · " .. host) or app.appName,
		bundleID = bundleID,
		windowId = window.id,
		tabId = tab.id,
		tabIndex = tab.index,
		url = tab.url,
	}
end

local REX_BUNDLE_ID = "com.superlogical.rex"
local WHATSAPP_BUNDLE_ID = "net.whatsapp.WhatsApp"
local MESSAGES_BUNDLE_ID = "com.apple.MobileSMS"
-- Values of ZWACHATSESSION.ZSESSIONTYPE and chat.style in the WhatsApp and Messages databases.
local WHATSAPP_CONTACT, WHATSAPP_GROUP = 0, 1
local IMESSAGE_GROUP = 43
-- Trailing digits compared when matching phone numbers, so "+49 151…" and "0151…" meet.
local PHONE_SUFFIX_DIGITS = 9

-- Apps whose own search can open a chat, with the menu path or shortcut that focuses that search. WhatsApp
-- prefixes its menu titles with an invisible left-to-right mark, so those names carry it too. Slack's
-- "Switch to Channel" menu item does not open the switcher when clicked, so it gets the shortcut; as an
-- Electron app (`electron`) it only reports focus inside its window once its accessibility tree is exposed.
M.APP_SEARCH = {
	[WHATSAPP_BUNDLE_ID] = { appName = "WhatsApp", menu = { "File", "\u{200E}Search" } },
	[MESSAGES_BUNDLE_ID] = { appName = "Messages", menu = { "Edit", "Find", "Find…" } },
	["com.tinyspeck.slackmacgap"] = { appName = "Slack", keys = { mods = { "cmd" }, key = "k" }, electron = true },
	["ru.keepcoder.Telegram"] = { appName = "Telegram", menu = { "Telegram", "Quick Search" } },
}
-- Order of the "Search <app> for …" rows under the matches.
local APP_SEARCH_ORDER = { WHATSAPP_BUNDLE_ID, MESSAGES_BUNDLE_ID, "com.tinyspeck.slackmacgap", "ru.keepcoder.Telegram" }

local function trim(text)
	return (text or ""):match("^%s*(.-)%s*$")
end

-- `windowOrder` lists every window most-recently-focused first: { id, bundleID, appName, title }.
-- `tabData` maps bundle IDs to { appName, windows = { { id, tabs = { { id, index, title, url, active } } } } },
-- with each app's windows front to back. Windows of apps present in `tabData` are shown as their tabs instead.
-- An app's front-to-back order matches its share of the focus order, so its k-th scripted window takes the
-- rank of its k-th focused window. Rows are every window and active tab by rank, then the remaining tabs,
-- then `extras` (already-built rows such as Rex tabs and chats) in the order given.
function M.buildChoices(windowOrder, tabData, extras)
	local ranked = {}
	local windowRank = {}
	local seenPerApp = {}

	for rank, window in ipairs(windowOrder) do
		local app = tabData[window.bundleID]
		if app then
			local k = (seenPerApp[window.bundleID] or 0) + 1
			seenPerApp[window.bundleID] = k
			if app.windows[k] then
				windowRank[app.windows[k]] = rank
			end
		else
			table.insert(ranked, { rank = rank, choice = windowChoice(window) })
		end
	end

	local bundleIDs = {}
	for bundleID in pairs(tabData) do
		table.insert(bundleIDs, bundleID)
	end
	table.sort(bundleIDs)

	local unranked = #windowOrder
	local rest = {}
	for _, bundleID in ipairs(bundleIDs) do
		local app = tabData[bundleID]
		for _, window in ipairs(app.windows) do
			if not windowRank[window] then
				unranked = unranked + 1
				windowRank[window] = unranked
			end
			for _, tab in ipairs(window.tabs) do
				local entry = { rank = windowRank[window], index = tab.index, choice = tabChoice(app, bundleID, window, tab) }
				table.insert(tab.active and ranked or rest, entry)
			end
		end
	end

	table.sort(ranked, function(a, b)
		return a.rank < b.rank
	end)
	table.sort(rest, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		return a.index < b.index
	end)

	local choices = {}
	for _, entry in ipairs(ranked) do
		table.insert(choices, entry.choice)
	end
	for _, entry in ipairs(rest) do
		table.insert(choices, entry.choice)
	end
	for _, choice in ipairs(extras or {}) do
		table.insert(choices, choice)
	end
	return choices
end

-- `sessions` is { { id, label, windows = { { id, label } } } }; each Rex window (a tab in the app) becomes a row.
function M.rexChoices(sessions)
	local choices = {}
	for _, session in ipairs(sessions) do
		for position, window in ipairs(session.windows) do
			local label = trim(window.label)
			table.insert(choices, {
				kind = "rex",
				text = label ~= "" and label or ("Tab " .. position),
				subText = "Rex · " .. session.label,
				bundleID = REX_BUNDLE_ID,
				sessionId = session.id,
				windowId = window.id,
			})
		end
	end
	return choices
end

-- `rows` come from ZWACHATSESSION, most recent first: { name, jid, type }. Only contacts with a phone
-- number jid have a deep link; WhatsApp has no link that opens a group, so those search the app by name.
function M.whatsappChoices(rows)
	local choices = {}
	for _, row in ipairs(rows) do
		if row.type == WHATSAPP_CONTACT or row.type == WHATSAPP_GROUP then
			local phone = row.type == WHATSAPP_CONTACT and (row.jid or ""):match("^(%d+)@s%.whatsapp%.net$")
			local choice = {
				text = trim(row.name) ~= "" and trim(row.name) or (row.jid or "WhatsApp chat"),
				bundleID = WHATSAPP_BUNDLE_ID,
			}
			if phone then
				choice.kind = "url"
				choice.url = "whatsapp://send?phone=" .. phone
				choice.subText = "WhatsApp · +" .. phone
			else
				choice.kind = "appSearch"
				choice.query = choice.text
				choice.subText = row.type == WHATSAPP_GROUP and "WhatsApp · group" or "WhatsApp"
			end
			table.insert(choices, choice)
		end
	end
	return choices
end

-- Normalises an email or phone number into the key `contactIndex` stores names under.
function M.contactKey(value)
	value = trim(value)
	if value:find("@", 1, true) then
		return value:lower()
	end
	local digits = value:gsub("%D", "")
	if digits == "" then
		return nil
	end
	return digits:sub(-PHONE_SUFFIX_DIGITS)
end

-- `rows` are { name, value } pairs of contact names with their phone numbers and emails.
function M.contactIndex(rows)
	local index = {}
	for _, row in ipairs(rows) do
		local name = trim(row.name)
		local key = M.contactKey(row.value)
		if name ~= "" and key then
			index[key] = name
		end
	end
	return index
end

-- `rows` come from the Messages chat table, most recent first: { identifier, style, displayName, members },
-- where `members` joins participant handles with "|". One-to-one chats deep link through sms:, which opens
-- the existing conversation in Messages; group chats have no link and search Messages by name instead.
function M.imessageChoices(rows, contacts)
	local function nameFor(handle)
		return contacts[M.contactKey(handle) or ""] or handle
	end

	local choices = {}
	for _, row in ipairs(rows) do
		if row.style == IMESSAGE_GROUP then
			local text = trim(row.displayName)
			if text == "" then
				local names = {}
				for handle in (row.members or ""):gmatch("[^|]+") do
					table.insert(names, nameFor(handle))
				end
				text = #names > 0 and table.concat(names, ", ") or row.identifier
			end
			table.insert(choices, {
				kind = "appSearch",
				text = text,
				query = text,
				subText = "Messages · group",
				bundleID = MESSAGES_BUNDLE_ID,
			})
		else
			table.insert(choices, {
				kind = "url",
				text = nameFor(row.identifier),
				subText = "Messages · " .. row.identifier,
				url = "sms:" .. row.identifier,
				bundleID = MESSAGES_BUNDLE_ID,
			})
		end
	end
	return choices
end

-- One "Search <app> for …" row per installed app in `installed` (a set of bundle IDs), so any chat can be
-- reached through the app's own search: Telegram's chat list is encrypted on disk, Slack's is not on disk
-- at all, and deep links do not cover every WhatsApp/Messages chat.
function M.appSearchChoices(query, installed)
	query = trim(query)
	local choices = {}
	if query == "" then
		return choices
	end
	for _, bundleID in ipairs(APP_SEARCH_ORDER) do
		if installed[bundleID] then
			local app = M.APP_SEARCH[bundleID]
			table.insert(choices, {
				kind = "appSearch",
				text = "Search " .. app.appName .. " for “" .. query .. "”",
				subText = app.appName,
				bundleID = bundleID,
				query = query,
			})
		end
	end
	return choices
end

-- Keeps the choices whose title, subtitle or url contain every whitespace-separated word of `query`.
function M.filter(choices, query)
	local words = {}
	for word in (query or ""):lower():gmatch("%S+") do
		table.insert(words, word)
	end
	if #words == 0 then
		return choices
	end

	local matches = {}
	for _, choice in ipairs(choices) do
		local haystack = table.concat({ choice.text or "", choice.subText or "", choice.url or "" }, " "):lower()
		local all = true
		for _, word in ipairs(words) do
			if not haystack:find(word, 1, true) then
				all = false
				break
			end
		end
		if all then
			table.insert(matches, choice)
		end
	end
	return matches
end

return M
