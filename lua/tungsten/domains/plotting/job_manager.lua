local config = require("tungsten.config")
local logger = require("tungsten.util.logger")

local M = {}

local job_queue = {}
local active_plot_jobs = {}
local next_id = 0

local function active_count()
	local n = 0
	for _ in pairs(active_plot_jobs) do
		n = n + 1
	end
	return n
end

local function _execute_plot(job)
	logger.debug(
		"Tungsten Debug",
		string.format("Starting plot job %s using backend %s", job.id, job.plot_opts.backend or "unknown")
	)
	-- Placeholder
end

local function _process_queue()
	local max_jobs = config.max_jobs or 3
	while #job_queue > 0 and active_count() < max_jobs do
		local job = table.remove(job_queue, 1)
		job.start_time = vim.loop.now()
		active_plot_jobs[job] =
			{ expression = job.plot_opts.expression, backend = job.plot_opts.backend, start_time = job.start_time }
		vim.schedule(function()
			_execute_plot(job)
		end)
	end
end

function M.submit(plot_opts, on_success, on_error)
	next_id = next_id + 1
	local job = { id = next_id, plot_opts = plot_opts, on_success = on_success, on_error = on_error }
	table.insert(job_queue, job)
	_process_queue()
	return job.id
end

M.active_jobs = active_plot_jobs
M._process_queue = _process_queue

return M
