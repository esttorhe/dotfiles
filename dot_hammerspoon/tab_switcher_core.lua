-- ABOUTME: Pure ordering and filtering logic for the tab switcher, kept free of hs.* so it runs under plain Lua.
-- ABOUTME: Merges focus-ordered windows with scripted browser/terminal tabs into one ranked list of chooser rows.

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

-- `windowOrder` lists every window most-recently-focused first: { id, bundleID, appName, title }.
-- `tabData` maps bundle IDs to { appName, windows = { { id, tabs = { { id, index, title, url, active } } } } },
-- with each app's windows front to back. Windows of apps present in `tabData` are shown as their tabs instead.
-- An app's front-to-back order matches its share of the focus order, so its k-th scripted window takes the
-- rank of its k-th focused window. Rows are every window and active tab by rank, then the remaining tabs.
function M.buildChoices(windowOrder, tabData)
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
