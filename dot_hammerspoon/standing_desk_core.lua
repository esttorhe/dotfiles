-- ABOUTME: Pure standing desk tracking logic (sessions, stats, reminders, Raycast import), free of hs.* so it runs under plain Lua.
-- ABOUTME: Timestamps are epoch milliseconds and durations whole seconds, matching the Raycast extension's data.

local M = {}

M.MOTIVATION_MESSAGES = {
	"💪 Time to stand up! Your body will thank you!",
	"🚶 Let's get moving! Stand up and stretch!",
	"⚡ You've been sitting for a while. Time to stand!",
	"🌟 Stand up for better health! You've got this!",
	"🏃 Your daily standing goal is calling!",
	"💡 Remember, standing is good for your health!",
	"👍 You're doing great! Keep it up!",
	"🎯 You're on track to reach your daily standing goal!",
	"👏 Great job! Keep standing for your health!",
	"💖 You're making a positive impact on your health!",
}

M.REST_MESSAGES = {
	"🪑 You've been up a while. Take a seat!",
	"🙃 Standing too long is hard on the back. Sit down for a bit!",
	"🦵 Give your legs a break. Time to sit!",
	"⚖️ Balance is the point. Sit down for a while!",
	"😌 Nice standing streak. Now rest those legs!",
	"🩺 Your knees called. They'd like you to sit!",
	"💪 You've earned a sit. Take it!",
	"🔄 Time to switch it up and sit down!",
}

-- Goal reminders only start in the afternoon, leaving the morning to build up standing time.
local GOAL_REMINDER_HOUR = 14

function M.emptyData()
	return { sessions = {}, current = nil, lastNotificationTime = nil, lastNotificationType = nil }
end

function M.formatDuration(seconds)
	seconds = math.floor(seconds)
	if seconds < 60 then
		return seconds .. "s"
	end

	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60

	if hours > 0 then
		if minutes > 0 then
			return string.format("%dh %dm", hours, minutes)
		end
		return hours .. "h"
	end

	if secs > 0 then
		return string.format("%dm %ds", minutes, secs)
	end
	return minutes .. "m"
end

-- Local-time start of the day, the Monday-based week, or the month containing nowMs.
function M.periodStart(period, nowMs)
	local t = os.date("*t", math.floor(nowMs / 1000))
	t.hour, t.min, t.sec = 0, 0, 0
	if period == "week" then
		-- os.date's wday is 1 for Sunday; count Sunday as the seventh day of the week.
		local daysSinceMonday = (t.wday + 5) % 7
		t.day = t.day - daysSinceMonday
	elseif period == "month" then
		t.day = 1
	end
	t.isdst = nil
	return os.time(t) * 1000
end

function M.sessionsForPeriod(sessions, period, nowMs)
	local cutoff = M.periodStart(period, nowMs)
	local out = {}
	for _, s in ipairs(sessions) do
		if s.startTime >= cutoff then
			out[#out + 1] = s
		end
	end
	return out
end

function M.calculateStats(sessions)
	local stats = {
		totalStanding = 0,
		totalSitting = 0,
		totalTime = 0,
		standingPercentage = 0,
		sittingPercentage = 0,
		sessionCount = #sessions,
		averageSessionDuration = 0,
		longestSession = 0,
		shortestSession = 0,
	}
	if #sessions == 0 then
		return stats
	end

	local longest, shortest = -math.huge, math.huge
	for _, s in ipairs(sessions) do
		if s.type == "standing" then
			stats.totalStanding = stats.totalStanding + s.duration
		else
			stats.totalSitting = stats.totalSitting + s.duration
		end
		longest = math.max(longest, s.duration)
		shortest = math.min(shortest, s.duration)
	end

	stats.totalTime = stats.totalStanding + stats.totalSitting
	if stats.totalTime > 0 then
		stats.standingPercentage = stats.totalStanding / stats.totalTime * 100
		stats.sittingPercentage = stats.totalSitting / stats.totalTime * 100
	end
	stats.averageSessionDuration = stats.totalTime / #sessions
	stats.longestSession = longest
	stats.shortestSession = shortest
	return stats
end

function M.elapsedSeconds(data, nowMs)
	if not data.current then
		return 0
	end
	return math.max(0, math.floor((nowMs - data.current.startTime) / 1000))
end

-- Recorded sessions plus the one in progress, which is only stored once it ends.
function M.withCurrent(data, nowMs)
	local all = {}
	for i, s in ipairs(data.sessions) do
		all[i] = s
	end
	if data.current then
		all[#all + 1] = {
			type = data.current.state,
			startTime = data.current.startTime,
			endTime = nowMs,
			duration = M.elapsedSeconds(data, nowMs),
		}
	end
	return all
end

function M.todayTotals(data, nowMs)
	local stats = M.calculateStats(M.sessionsForPeriod(M.withCurrent(data, nowMs), "day", nowMs))
	return stats.totalStanding, stats.totalSitting
end

-- Closes the running session at endsAt and records it. Returns the session, or nil if none was running.
local function endSession(data, endsAt)
	local current = data.current
	if not current then
		return nil
	end

	-- Never let a trimmed end time run behind the start and produce a negative duration.
	local endTime = math.floor(math.max(current.startTime, endsAt) + 0.5)
	local session = {
		type = current.state,
		startTime = current.startTime,
		endTime = endTime,
		duration = math.floor((endTime - current.startTime) / 1000),
	}
	data.sessions[#data.sessions + 1] = session
	data.current = nil
	return session
end

function M.start(data, state, nowMs)
	endSession(data, nowMs)
	data.current = { state = state, startTime = nowMs }
	-- The reminder bucket is per session; a stale one would make the next session skip that same mark.
	data.lastNotificationType = nil
end

function M.toggle(data, nowMs)
	local nextState = (data.current and data.current.state == "standing") and "sitting" or "standing"
	M.start(data, nextState, nowMs)
	return nextState
end

function M.stop(data, nowMs)
	return endSession(data, nowMs)
end

-- Stops tracking without recording anything, for a session that should never have been running.
function M.discard(data)
	data.current = nil
end

-- Time spent away from the machine is not time spent standing or sitting. Once idle past the
-- threshold, close the session at the moment input stopped so the idle stretch is not counted.
function M.autoPause(data, idleSeconds, prefs, nowMs)
	local threshold = prefs.autoPauseMinutes or 0
	if not data.current or threshold <= 0 or not idleSeconds or idleSeconds < threshold * 60 then
		return nil
	end
	return endSession(data, nowMs - idleSeconds * 1000)
end

local function pick(messages, rand)
	return messages[rand(#messages)]
end

-- Decides whether a reminder is due. Returns { kind, key, message } or nil.
-- rand(n) picks a message index in 1..n.
function M.reminder(data, prefs, nowMs, rand)
	rand = rand or math.random
	if not data.current then
		-- Tracking is stopped on purpose; "not tracking" is not "not standing".
		return nil
	end

	if data.lastNotificationTime then
		local minutesSince = (nowMs - data.lastNotificationTime) / 60000
		if minutesSince < prefs.notificationCooldownMinutes then
			return nil
		end
	end

	local state = data.current.state
	local minutes = M.elapsedSeconds(data, nowMs) / 60
	local warning = state == "sitting" and prefs.sittingWarningMinutes or prefs.standingWarningMinutes

	if minutes >= warning then
		local key = string.format("%s-%d", state, math.floor(minutes / 5) * 5)
		if data.lastNotificationType == key then
			return nil
		end
		local messages = state == "sitting" and M.MOTIVATION_MESSAGES or M.REST_MESSAGES
		local label = state == "sitting" and "Sitting" or "Standing"
		return {
			kind = state,
			key = key,
			message = string.format("%s (%s for %dm)", pick(messages, rand), label, math.floor(minutes)),
		}
	end

	if state ~= "sitting" then
		return nil
	end

	local hour = os.date("*t", math.floor(nowMs / 1000)).hour
	local standing = M.todayTotals(data, nowMs)
	local goalSeconds = prefs.dailyStandingGoalHours * 3600
	if hour < GOAL_REMINDER_HOUR or standing >= goalSeconds then
		return nil
	end

	return {
		kind = "goal",
		key = "standing-goal",
		message = string.format(
			"%s (%s today, %dm to goal)",
			pick(M.MOTIVATION_MESSAGES, rand),
			M.formatDuration(standing),
			math.ceil((goalSeconds - standing) / 60)
		),
	}
end

function M.markNotified(data, reminder, nowMs)
	data.lastNotificationTime = nowMs
	data.lastNotificationType = reminder.key
end

-- Merges a Raycast export ({ sessions, current }) into data. Sessions already present (same type
-- and start) are skipped, and the export's running session is adopted only if nothing runs here.
-- Returns how many sessions were added.
function M.importRaycast(data, export)
	local seen = {}
	for _, s in ipairs(data.sessions) do
		seen[s.type .. "@" .. s.startTime] = true
	end

	local added = 0
	for _, s in ipairs(export.sessions or {}) do
		local key = s.type .. "@" .. s.startTime
		if not seen[key] then
			seen[key] = true
			data.sessions[#data.sessions + 1] = {
				type = s.type,
				startTime = s.startTime,
				endTime = s.endTime,
				duration = s.duration,
			}
			added = added + 1
		end
	end

	table.sort(data.sessions, function(a, b)
		return a.startTime < b.startTime
	end)

	local current = export.current
	if not data.current and type(current) == "table" and current.state and current.startTime then
		data.current = { state = current.state, startTime = current.startTime }
	end
	return added
end

function M.progressBar(percentage, length)
	local filled = math.floor(percentage / 100 * length + 0.5)
	return string.rep("█", filled) .. string.rep("░", length - filled)
end

function M.stateSymbol(state)
	if state == "standing" then
		return "↑"
	elseif state == "sitting" then
		return "↓"
	end
	return "—"
end

function M.menuTitle(data, nowMs)
	if not data.current then
		return "— Not Tracking"
	end
	return M.stateSymbol(data.current.state) .. " " .. M.formatDuration(M.elapsedSeconds(data, nowMs))
end

return M
