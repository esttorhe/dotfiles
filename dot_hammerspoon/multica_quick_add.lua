-- ABOUTME: Floating quick-add panel that creates Multica issues from any app.
-- ABOUTME: Collects title/description/status/agent in an hs.webview and creates the issue via the multica CLI.

local M = {}

local MULTICA_BIN = "/opt/homebrew/bin/multica"
local MULTICA_CONFIG = os.getenv("HOME") .. "/.multica/config.json"
local SETTINGS_WORKSPACE_KEY = "multicaQuickAdd.workspaceId"
local SETTINGS_SELECTIONS_KEY = "multicaQuickAdd.selectionsByWorkspace"
local DEFAULT_STATUS_KEY = "todo"
local PANEL_WIDTH, PANEL_HEIGHT = 640, 320
-- "dark" or "light" to match the Multica app's theme, or "system" to follow macOS.
local THEME = "dark"

local panel = nil
local previousWindow = nil
local workspaces = nil
-- Agents and statuses per workspace id, fetched once per Hammerspoon session.
local workspaceOptions = {}

-- Tasks are kept referenced while running so they are not garbage collected mid-flight.
local runningTasks = {}

local function readFile(path)
	local file = assert(io.open(path, "r"))
	local contents = file:read("*a")
	file:close()
	return contents
end

local function sendToPanel(fn, payload)
	if panel then
		panel:evaluateJavaScript(string.format("%s(%s)", fn, hs.json.encode(payload)))
	end
end

local function showError(message)
	sendToPanel("showError", { message = message })
end

local function close()
	if panel then
		panel:delete()
		panel = nil
	end
	if previousWindow then
		previousWindow:focus()
		previousWindow = nil
	end
end

local function findWorkspace(workspaceId)
	for _, workspace in ipairs(workspaces or {}) do
		if workspace.id == workspaceId then
			return workspace
		end
	end
end

local function savedSelection(workspaceId)
	local selections = hs.settings.get(SETTINGS_SELECTIONS_KEY) or {}
	return selections[workspaceId] or {}
end

local function saveSelection(workspaceId, statusKey, agentId)
	local selections = hs.settings.get(SETTINGS_SELECTIONS_KEY) or {}
	selections[workspaceId] = { statusKey = statusKey, agentId = agentId }
	hs.settings.set(SETTINGS_SELECTIONS_KEY, selections)
	hs.settings.set(SETTINGS_WORKSPACE_KEY, workspaceId)
end

-- Runs the multica CLI and collects stdout through a streaming callback, because
-- hs.task otherwise stops draining the pipe at 64KB and the CLI blocks forever.
local function runMultica(args, input, callback)
	local chunks = {}
	local task
	task = hs.task.new(MULTICA_BIN, function(exitCode, stdout, stderr)
		runningTasks[task] = nil
		table.insert(chunks, stdout)
		callback(exitCode, table.concat(chunks), stderr)
	end, function(_, stdout)
		table.insert(chunks, stdout)
		return true
	end, args)
	runningTasks[task] = true
	task:start()
	if input then
		task:setInput(input)
	end
	task:closeInput()
end

local function pushWorkspaceOptions(workspaceId)
	local options = workspaceOptions[workspaceId]
	local selection = savedSelection(workspaceId)
	sendToPanel("setWorkspaceOptions", {
		workspaceId = workspaceId,
		agents = options.agents,
		statuses = options.statuses,
		selectedStatus = selection.statusKey or DEFAULT_STATUS_KEY,
		selectedAgent = selection.agentId or "",
	})
end

local function fetchAgents(workspaceId, callback)
	runMultica({ "--workspace-id", workspaceId, "agent", "list", "--output", "json" }, nil, function(exitCode, stdout, stderr)
		if exitCode ~= 0 then
			showError("Could not list agents: " .. stderr)
			return
		end
		local agents = {}
		for _, agent in ipairs(hs.json.decode(stdout)) do
			local avatar = agent.avatar_url or ""
			table.insert(agents, {
				id = agent.id,
				name = agent.name,
				emoji = avatar:match("^emoji:(.+)$") or "",
			})
		end
		table.sort(agents, function(a, b)
			return a.name:lower() < b.name:lower()
		end)
		callback(agents)
	end)
end

-- The CLI has no command for listing statuses, so this calls the same endpoint
-- the Multica app uses, authenticated with the CLI's own token.
local function fetchStatuses(workspaceId, callback)
	local config = hs.json.decode(readFile(MULTICA_CONFIG))
	local workspace = findWorkspace(workspaceId)
	local headers = {
		["Authorization"] = "Bearer " .. config.token,
		["X-Workspace-Slug"] = workspace.slug,
	}
	hs.http.asyncGet(config.server_url .. "/api/issue-statuses", headers, function(code, body)
		if code ~= 200 then
			showError(string.format("Could not list statuses (HTTP %s)", code))
			return
		end
		local statuses = {}
		for _, status in ipairs(hs.json.decode(body).statuses) do
			if status.archived_at == nil then
				table.insert(statuses, {
					key = status.key,
					name = status.name,
					color = status.color,
					position = status.position or 0,
				})
			end
		end
		table.sort(statuses, function(a, b)
			return a.position < b.position
		end)
		callback(statuses)
	end)
end

local function loadWorkspaceOptions(workspaceId)
	if workspaceOptions[workspaceId] then
		pushWorkspaceOptions(workspaceId)
		return
	end
	fetchAgents(workspaceId, function(agents)
		fetchStatuses(workspaceId, function(statuses)
			workspaceOptions[workspaceId] = { agents = agents, statuses = statuses }
			pushWorkspaceOptions(workspaceId)
		end)
	end)
end

local function pushWorkspaces()
	local selected = hs.settings.get(SETTINGS_WORKSPACE_KEY)
	if not findWorkspace(selected) then
		selected = workspaces[1].id
	end
	sendToPanel("setWorkspaces", { workspaces = workspaces, selected = selected })
	loadWorkspaceOptions(selected)
end

local function loadWorkspaces()
	if workspaces then
		pushWorkspaces()
		return
	end
	runMultica({ "workspace", "list", "--output", "json" }, nil, function(exitCode, stdout, stderr)
		if exitCode ~= 0 then
			showError("Could not list workspaces: " .. stderr)
			return
		end
		workspaces = hs.json.decode(stdout)
		pushWorkspaces()
	end)
end

local function createIssue(request)
	local args = {
		"--workspace-id",
		request.workspaceId,
		"issue",
		"create",
		"--title",
		request.title,
		"--status",
		request.statusKey,
		"--output",
		"json",
	}
	if request.agentId ~= "" then
		table.insert(args, "--assignee-id")
		table.insert(args, request.agentId)
	end
	local description = nil
	if request.description ~= nil and request.description ~= "" then
		description = request.description
		table.insert(args, "--description-stdin")
	end

	saveSelection(request.workspaceId, request.statusKey, request.agentId)
	runMultica(args, description, function(exitCode, stdout, stderr)
		if exitCode ~= 0 then
			showError(stderr ~= "" and stderr or stdout)
			return
		end
		local issue = hs.json.decode(stdout)
		local identifier = issue.identifier or issue.id
		hs.pasteboard.setContents(identifier)
		hs.notify.new({ title = "Multica issue created", informativeText = identifier .. " — " .. request.title }):send()
		close()
	end)
end

local function handleMessage(body)
	if body.action == "ready" then
		local dark = THEME == "dark" or (THEME == "system" and hs.host.interfaceStyle() == "Dark")
		sendToPanel("setTheme", { dark = dark })
		loadWorkspaces()
	elseif body.action == "workspaceChanged" then
		loadWorkspaceOptions(body.workspaceId)
	elseif body.action == "cancel" then
		close()
	elseif body.action == "submit" then
		createIssue(body)
	end
end

local function open()
	previousWindow = hs.window.focusedWindow()

	local screen = (previousWindow and previousWindow:screen() or hs.screen.mainScreen()):frame()
	local rect = hs.geometry.rect(
		screen.x + (screen.w - PANEL_WIDTH) / 2,
		screen.y + screen.h * 0.2,
		PANEL_WIDTH,
		PANEL_HEIGHT
	)

	local controller = hs.webview.usercontent.new("multica")
	controller:setCallback(function(message)
		handleMessage(message.body)
	end)

	-- Borderless and transparent so the HTML card (rounded, Multica-styled) is the whole window.
	panel = hs.webview.new(rect, {}, controller)
		:windowStyle({ "borderless" })
		:transparent(true)
		:shadow(true)
		:level(hs.drawing.windowLevels.floating)
		:behavior(hs.drawing.windowBehaviors.canJoinAllSpaces + hs.drawing.windowBehaviors.fullScreenAuxiliary)
		:allowTextEntry(true)
		:deleteOnClose(true)
		:windowCallback(function(action)
			if action == "closing" then
				panel = nil
			end
		end)
		:html(readFile(hs.configdir .. "/multica_quick_add.html"))
		:show()

	hs.focus()
	panel:hswindow():focus()
end

function M.toggle()
	if panel then
		close()
	else
		open()
	end
end

return M
