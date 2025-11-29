local M = {}

local function attach_error_translator(plot_opts, backend_module)
	if type(backend_module.translate_plot_error) == "function" then
		plot_opts._error_translator = backend_module.translate_plot_error
	else
		plot_opts._error_translator = nil
	end
end

function M.capture(plot_opts)
	local backend_name = plot_opts.backend or "wolfram"
	local ok_mod, backend_module = pcall(require, "tungsten.backends." .. backend_name)
	if not ok_mod then
		return nil, backend_module
	end

	attach_error_translator(plot_opts, backend_module)

	local build_plot_command = backend_module and backend_module.build_plot_command
	if type(build_plot_command) ~= "function" then
		return nil, string.format("Backend '%s' does not support plotting", backend_name)
	end

	local ok_call, command, command_opts_or_err = pcall(build_plot_command, vim.deepcopy(plot_opts))
	if not ok_call then
		return nil, command
	end
	if not command then
		return nil, command_opts_or_err or "Failed to prepare plot command"
	end

	return command, command_opts_or_err
end

return M
