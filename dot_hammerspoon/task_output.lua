-- ABOUTME: Runs a command with hs.task and hands its complete stdout/stderr to a callback once it exits.
-- ABOUTME: Shared by Hammerspoon modules that shell out to CLIs whose output can be large.

local M = {}

-- Tasks are kept referenced while running so they are not garbage collected mid-flight.
local runningTasks = {}

-- Sends stdout to a temp file read after exit. Without a streaming callback hs.task stops draining
-- the pipe at 64KB and the child blocks forever, and with one the last chunk can arrive after the
-- termination callback, truncating large outputs. `path` must be an absolute executable path.
function M.run(path, args, callback)
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

return M
