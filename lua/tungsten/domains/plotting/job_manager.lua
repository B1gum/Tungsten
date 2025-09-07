local config = require("tungsten.config")
local logger = require("tungsten.util.logger")
local async = require("tungsten.util.async")
local path = require("pl.path")
local error_handler = require("tungsten.util.error_handler")
local plotting_io = require("tungsten.util.plotting_io")

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

local function cleanup_temp(job)
	if job and job.plot_opts and job.plot_opts.temp_file then
		pcall(vim.loop.fs_unlink, job.plot_opts.temp_file)
	end
end

local function default_on_success(job, image_path)
	cleanup_temp(job)

	local bufnr = job.plot_opts.bufnr or vim.api.nvim_get_current_buf()
	local outputmode = job.plot_opts.outputmode or "Latex"

	if outputmode == "latex" or outputmode == "both" then
		local start_line = job.plot_opts.start_line or 0
		local end_line = plotting_io.find_math_block_end(bufnr, start_line)

		local buf_path = vim.api.nvim_buf_get_name(bufnr)
		local cwd = vim.fn.fnamemodify(buf_path, ":p:h")
		local rel_path = image_path
		local ok, rp = pcall(path.relpath, image_path, cwd)
		if ok and rp then
			rel_path = rp
		end

		local snippet = string.format("\\includegraphics[width=0.8\\linewidth]{%s}", rel_path)
		vim.api.nvim_buf_set_lines(bufnr, end_line + 1, end_line + 1, false, { snippet })
	end

	if outputmode == "viewer" or outputmode == "both" then
		local viewer_cmd
		if job.plot_opts.format == "png" then
			viewer_cmd = job.plot_opts.viewer_cmd_png or (config.plotting or {}).viewer_cmd_png
		else
			viewer_cmd = job.plot_opts.viewer_cmd_pdf or (config.plotting or {}).viewer_cmd_pdf
		end
		if viewer_cmd and viewer_cmd ~= "" then
			async.run_job({ viewer_cmd, image_path }, { on_exit = function() end })
		end
	end
end

local function default_on_error(job, err)
	cleanup_temp(job)

	local code = err and err.code
	local msg = err and err.message or ""
	local error_code
	if code == 127 then
		error_code = error_handler.E_BACKEND_UNAVAILABLE
	elseif code == 124 or msg:lower():find("timeout") then
		error_code = error_handler.E_TIMEOUT
	else
		error_code = error_handler.E_BACKEND_CRASH
	end
	error_handler.notify_error("TungstenPlot", error_code)
end

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
					job.on_error({ code = code, message = msg })
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

function M.submit(plot_opts, user_on_success, user_on_error)
	next_id = next_id + 1
	local job = { id = next_id, plot_opts = plot_opts }

	job.on_success = function(img_path)
		default_on_success(job, img_path)
		if user_on_success then
			user_on_success(img_path)
		end
	end

	job.on_error = function(err)
		default_on_error(job, err)
		if user_on_error then
			user_on_error(err)
		end
	end

	table.insert(job_queue, job)
	_process_queue()
	return job.id
end

M.active_jobs = active_plot_jobs
M._process_queue = _process_queue

return M
