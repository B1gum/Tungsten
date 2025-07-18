local actions_ok, actions = pcall(require, "telescope.actions")
local state_ok, action_state = pcall(require, "telescope.actions.state")
local logger = require("tungsten.util.logger")

local M = {}

function M.attach(prompt_bufnr, _)
	if not actions_ok or not state_ok then
		return false
	end

	actions.select_default:replace(function()
		actions.close(prompt_bufnr)
		local entry = action_state.get_selected_entry()

		if entry and entry.value then
			vim.cmd(entry.value)
		else
			logger.warn("No command selected")
		end
	end)
	return true
end

return M
