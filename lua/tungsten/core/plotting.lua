local job_manager = require("tungsten.domains.plotting.job_manager")
local plotting_io = require("tungsten.domains.plotting.io")

local M = {}

function M.initiate_plot(plot_opts, on_success, on_error)
	return job_manager.submit(plot_opts or {}, on_success, on_error)
end

function M.get_undefined_symbols(_opts)
	return true, {}
end

function M.generate_hash(plot_data)
	local opts = { filename_mode = "hash" }
	local generated = plotting_io.generate_filename(opts, plot_data or {})
	return generated:gsub("^plot_", "")
end

return M
