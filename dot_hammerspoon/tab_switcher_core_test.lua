-- ABOUTME: Plain-Lua tests for tab_switcher_core; run with `luajit tab_switcher_core_test.lua` from this directory.
-- ABOUTME: Covers choice ordering across windows and tabs, and multi-word query filtering.

package.path = "./?.lua;" .. package.path
local core = require("tab_switcher_core")

local failures, passed = 0, 0

local function test(name, fn)
	local ok, err = pcall(fn)
	if ok then
		passed = passed + 1
	else
		failures = failures + 1
		print("FAIL " .. name .. "\n  " .. tostring(err))
	end
end

local function eq(actual, expected, label)
	if actual ~= expected then
		error(string.format("%s: expected %s, got %s", label or "value", tostring(expected), tostring(actual)), 2)
	end
end

local function texts(choices)
	local out = {}
	for i, choice in ipairs(choices) do
		out[i] = choice.text
	end
	return table.concat(out, ",")
end

local dia = "company.thebrowser.dia"
local slack = "com.tinyspeck.slackmacgap"

local function diaTabs()
	return {
		[dia] = {
			appName = "Dia",
			windows = {
				{
					id = "W1",
					tabs = {
						{ id = "t1", index = 1, title = "Inbox", url = "https://mail.example.com/inbox", active = false },
						{ id = "t2", index = 2, title = "Calendar", url = "https://cal.example.com", active = true },
					},
				},
				{
					id = "W2",
					tabs = {
						{ id = "t3", index = 1, title = "Docs", url = "https://docs.example.com", active = true },
					},
				},
			},
		},
	}
end

test("plain windows keep focus order and carry their window id", function()
	local choices = core.buildChoices({
		{ id = 10, bundleID = slack, appName = "Slack", title = "general" },
		{ id = 11, bundleID = "com.apple.finder", appName = "Finder", title = "Downloads" },
	}, {})
	eq(texts(choices), "general,Downloads")
	eq(choices[1].kind, "window")
	eq(choices[1].windowId, 10)
	eq(choices[1].subText, "Slack")
end)

test("active tabs take their window's focus rank, other tabs follow", function()
	local choices = core.buildChoices({
		{ id = 1, bundleID = slack, appName = "Slack", title = "general" },
		{ id = 2, bundleID = dia, appName = "Dia", title = "Calendar" },
		{ id = 3, bundleID = dia, appName = "Dia", title = "Docs" },
	}, diaTabs())
	eq(texts(choices), "general,Calendar,Docs,Inbox")
end)

test("windows of a tab app are replaced by its tabs", function()
	local choices = core.buildChoices({
		{ id = 2, bundleID = dia, appName = "Dia", title = "Calendar" },
	}, diaTabs())
	for _, choice in ipairs(choices) do
		eq(choice.kind, "tab", choice.text)
	end
end)

test("tab windows missing from the focus list still appear, after ranked ones", function()
	local choices = core.buildChoices({
		{ id = 1, bundleID = slack, appName = "Slack", title = "general" },
	}, diaTabs())
	eq(texts(choices), "general,Calendar,Docs,Inbox")
end)

test("tab choices carry what activation needs and show host in subtitle", function()
	local choices = core.buildChoices({}, diaTabs())
	local calendar = choices[1]
	eq(calendar.kind, "tab")
	eq(calendar.bundleID, dia)
	eq(calendar.windowId, "W1")
	eq(calendar.tabId, "t2")
	eq(calendar.tabIndex, 2)
	eq(calendar.subText, "Dia · cal.example.com")
	eq(calendar.url, "https://cal.example.com")
end)

test("tabs without a url use the app name as subtitle", function()
	local choices = core.buildChoices({}, {
		["com.mitchellh.ghostty"] = {
			appName = "Ghostty",
			windows = { { id = "G1", tabs = { { id = "g1", index = 1, title = "fish", active = true } } } },
		},
	})
	eq(choices[1].subText, "Ghostty")
end)

test("untitled windows fall back to the app name", function()
	local choices = core.buildChoices({ { id = 5, bundleID = slack, appName = "Slack", title = "" } }, {})
	eq(choices[1].text, "Slack")
end)

test("filter with empty query returns everything", function()
	local choices = core.buildChoices({}, diaTabs())
	eq(#core.filter(choices, ""), 3)
	eq(#core.filter(choices, "   "), 3)
end)

test("filter matches every word case-insensitively across title, app and url", function()
	local choices = core.buildChoices({}, diaTabs())
	eq(texts(core.filter(choices, "CAL")), "Calendar")
	eq(texts(core.filter(choices, "dia docs")), "Docs")
	eq(texts(core.filter(choices, "mail.example inbox")), "Inbox")
	eq(#core.filter(choices, "dia nothing"), 0)
end)

test("filter treats punctuation literally", function()
	local choices = core.buildChoices({ { id = 1, bundleID = slack, appName = "Slack", title = "50% (draft)" } }, {})
	eq(texts(core.filter(choices, "50% (dr")), "50% (draft)")
end)

print(string.format("%d passed, %d failed", passed, failures))
os.exit(failures == 0 and 0 or 1)
