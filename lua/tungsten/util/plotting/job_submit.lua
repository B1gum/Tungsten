local backend_command = require("tungsten.domains.plotting.workflow.backend_command")
local job_manager = require("tungsten.domains.plotting.job_manager")

local M = {}

function M.submit(plot_opts, notify_error, fallback_error_code)
	if type(plot_opts) ~= "table" then
		return
	end

	local command, command_opts = backend_command.capture(plot_opts)
	if not command then
		if notify_error then
			notify_error(command_opts, nil, nil, fallback_error_code)
		end
		return
	end

	for i = 1, #command do
		plot_opts[i] = command[i]
	end

	if command_opts and command_opts.timeout then
		plot_opts.timeout_ms = command_opts.timeout
	end

	job_manager.submit(plot_opts)
end

return M
