local config = require("tungsten.config")
local logger = require("tungsten.util.logger")
local async = require("tungsten.util.async")

local M = {}

local job_queue = {}
local active_plot_jobs = {}
local next_id = 0
local spinner_ns = vim.api.nvim_create_namespace("tungsten_plot_spinner")

local function active_count()
	local n = 0
	for _ in pairs(active_plot_jobs) do
		n = n + 1
	end
	return n
end

local _process_queue

local function _execute_plot(job)
	logger.debug(
		"Tungsten Debug",
		string.format("Starting plot job %s using backend %s", job.id, job.plot_opts.backend or "unknown")
	)

	local info = active_plot_jobs[job.id] or {}
	job.start_time = vim.loop.now()
	info.start_time = job.start_time

	local bufnr = job.plot_opts.bufnr or vim.api.nvim_get_current_buf()
	local row = job.plot_opts.end_line or job.plot_opts.start_line or 0
	local col = job.plot_opts.end_col or job.plot_opts.start_col or 0
	local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, spinner_ns, row, col, {
		virt_text = { { "Plotting..." } },
		virt_text_pos = "eol",
	})
	info.extmark_id = extmark_id
	info.bufnr = bufnr
	info.expression = job.plot_opts.expression
	info.backend = job.plot_opts.backend
	active_plot_jobs[job.id] = info

	async.run_job(job.plot_opts, {
		on_exit = function(code, stdout, stderr)
			if info.extmark_id then
				pcall(vim.api.nvim_buf_del_extmark, info.bufnr, spinner_ns, info.extmark_id)
			end
			active_plot_jobs[job.id] = nil

			if code == 0 then
				if job.on_success then
					job.on_success(stdout)
				end
			else
				if job.on_error then
					local msg = stderr ~= "" and stderr or stdout
					job.on_error(msg)
				end
			end
			_process_queue()
		end,
	})
end

_process_queue = function()
	local max_jobs = config.max_jobs or 3
	while #job_queue > 0 and active_count() < max_jobs do
		local job = table.remove(job_queue, 1)
		active_plot_jobs[job.id] = {}
		_execute_plot(job)
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
