local wezterm = require("wezterm")

local M = {}

function M.apply_to_config(config)
	config.keys = {
		{ key = "1", mods = "CMD", action = wezterm.action.SendString("\x021") },
		{ key = "2", mods = "CMD", action = wezterm.action.SendString("\x022") },
		{ key = "3", mods = "CMD", action = wezterm.action.SendString("\x023") },
		{ key = "4", mods = "CMD", action = wezterm.action.SendString("\x024") },
		{ key = "5", mods = "CMD", action = wezterm.action.SendString("\x025") },
		{ key = "6", mods = "CMD", action = wezterm.action.SendString("\x026") },
		{ key = "7", mods = "CMD", action = wezterm.action.SendString("\x027") },
		{ key = "8", mods = "CMD", action = wezterm.action.SendString("\x028") },
		{ key = "9", mods = "CMD", action = wezterm.action.SendString("\x029") },
		{ key = ",", mods = "CMD", action = wezterm.action.SendString("\x02,") },
		{ key = "E", mods = "CMD", action = wezterm.action.SendString('\x02"') },
		{ key = "E", mods = "CMD|SHIFT", action = wezterm.action.SendString("\x02%") },
		{ key = "Q", mods = "CTRL", action = wezterm.action.SendString(":q\n") },
		{ key = "S", mods = "CMD", action = wezterm.action.SendString("\x1bw\n") },
		{ key = "S", mods = "CTRL", action = wezterm.action.SendString("\x1bw\n") },
		{ key = "S", mods = "CMD|SHIFT", action = wezterm.action.SendString(":wa\n") },
		{ key = ";", mods = "CTRL", action = wezterm.action.SendString("\x02:") },
		{ key = "T", mods = "CMD", action = wezterm.action.SendString("\x02c") },
		{ key = "W", mods = "CMD", action = wezterm.action.SendString("\x02x") },
		{ key = "Z", mods = "CMD", action = wezterm.action.SendString("\x02z") },
	}
end

return M
