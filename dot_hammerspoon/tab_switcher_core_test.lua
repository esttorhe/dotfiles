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

test("extra rows are appended after windows and tabs in the given order", function()
	local choices = core.buildChoices({ { id = 1, bundleID = slack, appName = "Slack", title = "general" } }, diaTabs(), {
		{ kind = "rex", text = "editor" },
		{ kind = "url", text = "Mum" },
	})
	eq(texts(choices), "general,Calendar,Docs,Inbox,editor,Mum")
end)

test("rex tabs become rows that name their session", function()
	local choices = core.rexChoices({
		{
			id = "session:1",
			label = "infra",
			windows = { { id = "window:a", label = "hammerspoon" }, { id = "window:b", label = "" } },
		},
	})
	eq(texts(choices), "hammerspoon,Tab 2")
	eq(choices[1].kind, "rex")
	eq(choices[1].subText, "Rex · infra")
	eq(choices[1].sessionId, "session:1")
	eq(choices[1].windowId, "window:a")
	eq(choices[1].bundleID, "com.superlogical.rex")
end)

test("whatsapp contacts get a send deep link, groups and unknown ids search the app by name", function()
	local choices = core.whatsappChoices({
		{ name = "Mum", jid = "4915112345678@s.whatsapp.net", type = 0 },
		{ name = "Socks and sandals ", jid = "123-456@g.us", type = 1 },
		{ name = "Hidden", jid = "987@lid", type = 0 },
		{ name = "‎WhatsApp", jid = "0@status", type = 3 },
		{ name = "News", jid = "1@newsletter", type = 5 },
	})
	eq(texts(choices), "Mum,Socks and sandals,Hidden")
	eq(choices[1].kind, "url")
	eq(choices[1].url, "whatsapp://send?phone=4915112345678")
	eq(choices[1].subText, "WhatsApp · +4915112345678")
	eq(choices[2].kind, "appSearch")
	eq(choices[2].query, "Socks and sandals")
	eq(choices[2].subText, "WhatsApp · group")
	eq(choices[2].bundleID, "net.whatsapp.WhatsApp")
	eq(choices[3].kind, "appSearch")
	eq(choices[3].query, "Hidden")
end)

test("contact index matches phone numbers regardless of formatting and country prefix", function()
	local index = core.contactIndex({
		{ name = "Mum", value = "+49 (151) 123-45678" },
		{ name = "Bob", value = "Bob@Example.com" },
		{ name = "", value = "+1 555 0100" },
	})
	eq(index[core.contactKey("+4915112345678")], "Mum")
	eq(index[core.contactKey("015112345678")], "Mum")
	eq(index[core.contactKey("bob@example.com")], "Bob")
	eq(index[core.contactKey("+15550100")], nil)
end)

test("imessage chats use contact names, deep link one-to-one chats and search groups by name", function()
	local contacts = core.contactIndex({
		{ name = "Mum", value = "+4915112345678" },
		{ name = "Bob", value = "bob@example.com" },
	})
	local choices = core.imessageChoices({
		{ identifier = "+4915112345678", style = 45, displayName = "", members = "+4915112345678" },
		{ identifier = "+15550100", style = 45, displayName = "", members = "+15550100" },
		{ identifier = "chat123", style = 43, displayName = "", members = "+4915112345678|bob@example.com" },
		{ identifier = "chat456", style = 43, displayName = "Family", members = "+4915112345678" },
	}, contacts)
	eq(texts(choices), "Mum,+15550100,Mum, Bob,Family")
	eq(choices[1].kind, "url")
	eq(choices[1].url, "sms:+4915112345678")
	eq(choices[1].subText, "Messages · +4915112345678")
	eq(choices[3].kind, "appSearch")
	eq(choices[3].query, "Mum, Bob")
	eq(choices[3].subText, "Messages · group")
	eq(choices[3].bundleID, "com.apple.MobileSMS")
end)

test("app search rows exist only for a non-blank query and installed apps, in a fixed order", function()
	local installed = {
		["ru.keepcoder.Telegram"] = true,
		["com.tinyspeck.slackmacgap"] = true,
		["net.whatsapp.WhatsApp"] = true,
	}
	eq(#core.appSearchChoices("", installed), 0)
	eq(#core.appSearchChoices("  ", installed), 0)
	local choices = core.appSearchChoices(" ola ", installed)
	eq(texts(choices), "Search WhatsApp for “ola”,Search Slack for “ola”,Search Telegram for “ola”")
	eq(choices[1].kind, "appSearch")
	eq(choices[1].query, "ola")
	eq(choices[1].bundleID, "net.whatsapp.WhatsApp")
	eq(choices[1].subText, "WhatsApp")
end)

test("every searchable app names a menu item or a shortcut that opens its search", function()
	for _, bundleID in ipairs({ "net.whatsapp.WhatsApp", "com.apple.MobileSMS", "com.tinyspeck.slackmacgap", "ru.keepcoder.Telegram" }) do
		local app = core.APP_SEARCH[bundleID]
		eq(type(app.appName), "string", bundleID)
		eq(type(app.menu) == "table" or type(app.keys) == "table", true, bundleID)
	end
end)

test("slack opens its channel switcher with cmd+k and needs its accessibility tree exposed", function()
	local slack = core.APP_SEARCH["com.tinyspeck.slackmacgap"]
	eq(slack.menu, nil)
	eq(slack.keys.key, "k")
	eq(slack.keys.mods[1], "cmd")
	eq(slack.electron, true)
end)

print(string.format("%d passed, %d failed", passed, failures))
os.exit(failures == 0 and 0 or 1)
