-- ABOUTME: Plain-Lua tests for standing_desk_core; run with `luajit standing_desk_core_test.lua` from this directory.
-- ABOUTME: Covers duration formatting, period filtering, stats, session transitions, auto-pause, reminders and Raycast import.

package.path = "./?.lua;" .. package.path
local core = require("standing_desk_core")

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

-- Milliseconds for a local wall-clock time, matching how the tracker stores timestamps.
local function at(year, month, day, hour, min, sec)
	return os.time({ year = year, month = month, day = day, hour = hour, min = min or 0, sec = sec or 0 }) * 1000
end

local MIN = 60 * 1000

local function prefs(overrides)
	local p = {
		sittingWarningMinutes = 30,
		standingWarningMinutes = 30,
		dailyStandingGoalHours = 3,
		notificationCooldownMinutes = 10,
		autoPauseMinutes = 15,
	}
	for k, v in pairs(overrides or {}) do
		p[k] = v
	end
	return p
end

local function firstPick()
	return 1
end

test("formatDuration matches the Raycast formatting", function()
	eq(core.formatDuration(0), "0s")
	eq(core.formatDuration(45), "45s")
	eq(core.formatDuration(60), "1m")
	eq(core.formatDuration(2687), "44m 47s")
	eq(core.formatDuration(3600), "1h")
	eq(core.formatDuration(3660), "1h 1m")
	eq(core.formatDuration(3661), "1h 1m")
	eq(core.formatDuration(59.7), "59s", "fractional seconds are floored")
end)

test("periodStart returns local midnight, Monday and the first of the month", function()
	-- 2026-11-04 is a Wednesday.
	local now = at(2026, 11, 4, 15, 30)
	eq(core.periodStart("day", now), at(2026, 11, 4, 0))
	eq(core.periodStart("week", now), at(2026, 11, 2, 0))
	eq(core.periodStart("month", now), at(2026, 11, 1, 0))
end)

test("periodStart treats Sunday as the end of the week, not the start", function()
	local sunday = at(2026, 11, 8, 10)
	eq(core.periodStart("week", sunday), at(2026, 11, 2, 0))
end)

test("sessionsForPeriod keeps sessions that started on or after the cutoff", function()
	local now = at(2026, 11, 4, 15)
	local sessions = {
		{ type = "sitting", startTime = at(2026, 11, 3, 23), endTime = at(2026, 11, 3, 23, 30), duration = 1800 },
		{ type = "standing", startTime = at(2026, 11, 4, 9), endTime = at(2026, 11, 4, 10), duration = 3600 },
	}
	local today = core.sessionsForPeriod(sessions, "day", now)
	eq(#today, 1)
	eq(today[1].type, "standing")
	eq(#core.sessionsForPeriod(sessions, "week", now), 2)
end)

test("calculateStats on no sessions is all zeros", function()
	local s = core.calculateStats({})
	eq(s.totalTime, 0)
	eq(s.sessionCount, 0)
	eq(s.standingPercentage, 0)
	eq(s.longestSession, 0)
end)

test("calculateStats totals, percentages and session extremes", function()
	local s = core.calculateStats({
		{ type = "standing", duration = 600 },
		{ type = "sitting", duration = 1800 },
		{ type = "sitting", duration = 600 },
	})
	eq(s.totalStanding, 600)
	eq(s.totalSitting, 2400)
	eq(s.totalTime, 3000)
	eq(s.standingPercentage, 20)
	eq(s.sittingPercentage, 80)
	eq(s.sessionCount, 3)
	eq(s.averageSessionDuration, 1000)
	eq(s.longestSession, 1800)
	eq(s.shortestSession, 600)
end)

test("withCurrent appends the in-progress session without touching the stored list", function()
	local data = {
		sessions = { { type = "sitting", startTime = 0, endTime = 1000, duration = 1 } },
		current = { state = "standing", startTime = 10 * MIN },
	}
	local all = core.withCurrent(data, 15 * MIN)
	eq(#all, 2)
	eq(all[2].type, "standing")
	eq(all[2].duration, 300)
	eq(#data.sessions, 1, "stored sessions untouched")
end)

test("start begins a session and records the previous one", function()
	local data = core.emptyData()
	core.start(data, "sitting", 0)
	eq(data.current.state, "sitting")
	eq(#data.sessions, 0)

	core.start(data, "standing", 20 * MIN)
	eq(data.current.state, "standing")
	eq(data.current.startTime, 20 * MIN)
	eq(#data.sessions, 1)
	eq(data.sessions[1].type, "sitting")
	eq(data.sessions[1].duration, 1200)
end)

test("start clears the per-session reminder bucket", function()
	local data = core.emptyData()
	data.lastNotificationType = "sitting-30"
	core.start(data, "sitting", 0)
	eq(data.lastNotificationType, nil)
end)

test("toggle starts standing when idle and flips otherwise", function()
	local data = core.emptyData()
	eq(core.toggle(data, 0), "standing")
	eq(core.toggle(data, MIN), "sitting")
	eq(core.toggle(data, 2 * MIN), "standing")
	eq(#data.sessions, 2)
end)

test("stop records the session and leaves nothing running", function()
	local data = core.emptyData()
	core.start(data, "standing", 0)
	local session = core.stop(data, 5 * MIN)
	eq(session.duration, 300)
	eq(data.current, nil)
	eq(#data.sessions, 1)
	eq(core.stop(data, 6 * MIN), nil, "stopping twice records nothing")
end)

test("discard stops without recording", function()
	local data = core.emptyData()
	core.start(data, "sitting", 0)
	core.discard(data)
	eq(data.current, nil)
	eq(#data.sessions, 0)
end)

test("an end time before the start never produces a negative duration", function()
	local data = core.emptyData()
	core.start(data, "sitting", 10 * MIN)
	local session = core.stop(data, 5 * MIN)
	eq(session.duration, 0)
	eq(session.endTime, 10 * MIN)
end)

test("autoPause trims idle time off the session once past the threshold", function()
	local data = core.emptyData()
	core.start(data, "sitting", 0)
	eq(core.autoPause(data, 14 * 60, prefs(), 60 * MIN), nil, "below threshold keeps tracking")
	eq(data.current.state, "sitting")

	local session = core.autoPause(data, 20 * 60, prefs(), 60 * MIN)
	eq(session.duration, 40 * 60)
	eq(data.current, nil)
end)

test("autoPause is disabled by a zero threshold", function()
	local data = core.emptyData()
	core.start(data, "sitting", 0)
	eq(core.autoPause(data, 9999, prefs({ autoPauseMinutes = 0 }), 60 * MIN), nil)
	eq(data.current.state, "sitting")
end)

test("todayTotals includes the running session", function()
	local now = at(2026, 11, 4, 12)
	local data = core.emptyData()
	data.sessions = {
		{ type = "standing", startTime = at(2026, 11, 4, 9), endTime = at(2026, 11, 4, 10), duration = 3600 },
	}
	data.current = { state = "sitting", startTime = now - 10 * MIN }
	local standing, sitting = core.todayTotals(data, now)
	eq(standing, 3600)
	eq(sitting, 600)
end)

test("reminder nags after sitting too long, once per 5-minute bucket", function()
	local data = core.emptyData()
	local start = at(2026, 11, 4, 10)
	core.start(data, "sitting", start)
	eq(core.reminder(data, prefs(), start + 29 * MIN, firstPick), nil)

	local r = core.reminder(data, prefs(), start + 31 * MIN, firstPick)
	eq(r.key, "sitting-30")
	eq(r.kind, "sitting")
	assert(r.message:find("Sitting for 31m"), r.message)
	core.markNotified(data, r, start + 31 * MIN)

	eq(core.reminder(data, prefs({ notificationCooldownMinutes = 1 }), start + 34 * MIN, firstPick), nil, "same bucket stays quiet")
	eq(core.reminder(data, prefs(), start + 40 * MIN, firstPick), nil, "cooldown blocks the next bucket")
	eq(core.reminder(data, prefs(), start + 46 * MIN, firstPick).key, "sitting-45")
end)

test("reminder tells you to sit after standing too long", function()
	local data = core.emptyData()
	local start = at(2026, 11, 4, 10)
	core.start(data, "standing", start)
	local r = core.reminder(data, prefs(), start + 35 * MIN, firstPick)
	eq(r.kind, "standing")
	eq(r.key, "standing-35")
	assert(r.message:find("Standing for 35m"), r.message)
end)

test("reminder nudges toward the daily goal after 2 PM while sitting", function()
	local data = core.emptyData()
	core.start(data, "sitting", at(2026, 11, 4, 14, 50))
	local r = core.reminder(data, prefs(), at(2026, 11, 4, 15), firstPick)
	eq(r.kind, "goal")
	assert(r.message:find("0s today, 180m to goal", 1, true), r.message)
	eq(core.reminder(data, prefs(), at(2026, 11, 4, 13), firstPick), nil, "not before 2 PM")
end)

test("reminder stays quiet when nothing is being tracked", function()
	local data = core.emptyData()
	eq(core.reminder(data, prefs(), at(2026, 11, 4, 16), firstPick), nil)
end)

test("importRaycast merges sessions once and adopts the running session", function()
	local data = core.emptyData()
	local export = {
		sessions = {
			{ type = "sitting", startTime = 1000, endTime = 61000, duration = 60 },
			{ type = "standing", startTime = 61000, endTime = 121000, duration = 60 },
		},
		current = { state = "sitting", startTime = 121000 },
	}
	eq(core.importRaycast(data, export), 2)
	eq(#data.sessions, 2)
	eq(data.current.state, "sitting")
	eq(data.current.startTime, 121000)

	eq(core.importRaycast(data, export), 0, "re-importing adds nothing")
	eq(#data.sessions, 2)
end)

test("importRaycast keeps a session already running here", function()
	local data = core.emptyData()
	core.start(data, "standing", 500000)
	core.importRaycast(data, { sessions = {}, current = { state = "sitting", startTime = 121000 } })
	eq(data.current.state, "standing")
end)

test("importRaycast keeps sessions sorted by start time", function()
	local data = core.emptyData()
	data.sessions = { { type = "sitting", startTime = 5000, endTime = 6000, duration = 1 } }
	core.importRaycast(data, { sessions = { { type = "standing", startTime = 1000, endTime = 2000, duration = 1 } } })
	eq(data.sessions[1].startTime, 1000)
	eq(data.sessions[2].startTime, 5000)
end)

test("progressBar splits the bar by percentage", function()
	eq(core.progressBar(25, 4), "█░░░")
	eq(core.progressBar(0, 4), "░░░░")
	eq(core.progressBar(100, 4), "████")
end)

test("menuTitle shows the arrow and elapsed time, or not tracking", function()
	local data = core.emptyData()
	eq(core.menuTitle(data, 0), "— Not Tracking")
	core.start(data, "sitting", 0)
	eq(core.menuTitle(data, (44 * 60 + 47) * 1000), "↓ 44m 47s")
	core.start(data, "standing", 0)
	eq(core.menuTitle(data, 5000), "↑ 5s")
end)

test("sanitizePrefs fills missing keys from the defaults", function()
	local p, err = core.sanitizePrefs({ sittingWarningMinutes = 45 })
	eq(err, nil)
	eq(p.sittingWarningMinutes, 45)
	eq(p.standingWarningMinutes, core.DEFAULT_PREFS.standingWarningMinutes)
	eq(p.notificationStyle, "both")
end)

test("sanitizePrefs accepts numbers sent as strings from the form", function()
	local p, err = core.sanitizePrefs({ dailyStandingGoalHours = "2.5", autoPauseMinutes = "0" })
	eq(err, nil)
	eq(p.dailyStandingGoalHours, 2.5)
	eq(p.autoPauseMinutes, 0)
end)

test("sanitizePrefs rejects non-numeric and negative values, naming the field", function()
	local p, err = core.sanitizePrefs({ sittingWarningMinutes = "soon" })
	eq(p, nil)
	assert(err:find("Sitting reminder", 1, true), err)
	local _, err2 = core.sanitizePrefs({ notificationCooldownMinutes = -1 })
	assert(err2:find("Reminder cooldown", 1, true), err2)
end)

test("sanitizePrefs rejects a zero warning, which would remind constantly", function()
	local _, err = core.sanitizePrefs({ standingWarningMinutes = 0 })
	assert(err:find("Standing reminder", 1, true), err)
end)

test("sanitizePrefs rejects an unknown reminder style", function()
	local _, err = core.sanitizePrefs({ notificationStyle = "carrier pigeon" })
	assert(err:find("Reminder style", 1, true), err)
end)

test("sanitizePrefs drops unknown keys", function()
	local p = core.sanitizePrefs({ bogus = 1 })
	eq(p.bogus, nil)
end)

print(string.format("%d passed, %d failed", passed, failures))
os.exit(failures == 0 and 0 or 1)
