local config = require("tungsten.config")
local logger = require("tungsten.util.logger")
local async = require("tungsten.util.async")
local path = require("pl.path")
local error_handler = require("tungsten.util.error_handler")
local plotting_io = require("tungsten.util.plotting_io")
local health = require("tungsten.domains.plotting.health")

local M = {}

local job_queue = {}
local active_plot_jobs = {}
local next_id = 0
local spinner_ns = vim.api.nvim_create_namespace("tungsten_plot_spinner")
local spinner_frames = {
	"⠋",
	"⠙",
	"⠹",
	"⠸",
	"⠼",
	"⠴",
	"⠦",
	"⠧",
	"⠇",
	"⠏",
}
local spinner_interval = 80

local deps_ok
local missing_message
local dependency_waiters = {}
local dependency_check_in_flight = false
local pending_dependency_jobs = {}
local dependency_failure_notified = false

local function resolve_dependency_waiters(ok, message, report)
	deps_ok = ok
	missing_message = message
	dependency_failure_notified = false

	local waiters = dependency_waiters
	dependency_waiters = {}
	for _, waiter in ipairs(waiters) do
		waiter(ok, message, report)
	end
end

local function evaluate_dependency_report(report)
	local function fmt_missing(name, info)
		if info and info.message then
			local required, found = info.message:match("required%s+([%d%.]+)%+, found%s+([%w%.]+)")
			if required and found then
				return string.format("%s %s < %s", name, found, required)
			end
		end
		return name
	end

	local missing = {}
	if not report.wolframscript.ok then
		table.insert(missing, fmt_missing("wolframscript", report.wolframscript))
	end
	if not report.python.ok then
		table.insert(missing, fmt_missing("python", report.python))
	end
	if not report.matplotlib.ok then
		table.insert(missing, fmt_missing("matplotlib", report.matplotlib))
	end
	if not report.sympy.ok then
		table.insert(missing, fmt_missing("sympy", report.sympy))
	end

	if #missing > 0 then
		return false, "Missing dependencies: " .. table.concat(missing, ", ")
	end

	return true, nil
end

local function on_dependencies_ready(callback)
	if deps_ok ~= nil then
		callback(deps_ok, missing_message)
		return
	end

	table.insert(dependency_waiters, callback)

	if dependency_check_in_flight then
		return
	end

	dependency_check_in_flight = true
	health.check_dependencies(function(report)
		dependency_check_in_flight = false
		local ok, message = evaluate_dependency_report(report)
		resolve_dependency_waiters(ok, message, report)
	end)
end

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

local function apply_output(plot_opts, image_path)
	if not plot_opts then
		return
	end

	local bufnr = plot_opts.bufnr or vim.api.nvim_get_current_buf()
	local outputmode = plot_opts.outputmode
	if type(outputmode) == "string" then
		outputmode = string.lower(outputmode)
	else
		outputmode = "latex"
	end

	if outputmode == "latex" or outputmode == "both" then
		local start_line = plot_opts.start_line or 0
		local end_line = plotting_io.find_math_block_end(bufnr, start_line)

		if not end_line then
			end_line = plot_opts.end_line or start_line
			logger.debug(
				"TungstenPlot",
				"Display math block is missing a closing delimiter; inserting plot snippet at selection end."
			)
		end

		local buf_path = vim.api.nvim_buf_get_name(bufnr)
		local cwd = vim.fn.fnamemodify(buf_path, ":p:h")
		local tex_root_dir
		if plot_opts.tex_root and plot_opts.tex_root ~= "" then
			tex_root_dir = path.dirname(plot_opts.tex_root)
		end
		if not tex_root_dir or tex_root_dir == "" then
			tex_root_dir = cwd
		end

		local snippet_width = plot_opts.snippet_width or (config.plotting or {}).snippet_width or "0.8\\linewidth"

		local snippet_path
		if plot_opts.uses_graphicspath then
			local filename = path.basename(image_path) or image_path
			local base, ext = path.splitext(filename)
			local basename = filename
			if base and ext and ext ~= "" then
				basename = base
			end
			snippet_path = string.format("tungsten_plots/%s", basename)
		else
			local rel_path = image_path
			local ok, rp = pcall(path.relpath, image_path, tex_root_dir)
			if ok and rp then
				rel_path = rp
			end

			local base, ext = path.splitext(rel_path)
			snippet_path = rel_path
			if base and ext and ext ~= "" then
				snippet_path = base
			end
		end

		local snippet = string.format("\\includegraphics[width=%s]{%s}", snippet_width, snippet_path)
		vim.api.nvim_buf_set_lines(bufnr, end_line + 1, end_line + 1, false, { snippet })
	end

	if outputmode == "viewer" or outputmode == "both" then
		local viewer_cmd
		if plot_opts.format == "png" then
			viewer_cmd = plot_opts.viewer_cmd_png or (config.plotting or {}).viewer_cmd_png
		else
			viewer_cmd = plot_opts.viewer_cmd_pdf or (config.plotting or {}).viewer_cmd_pdf
		end
		if viewer_cmd and viewer_cmd ~= "" then
			async.run_job({ viewer_cmd, image_path }, {
				on_exit = function(code, stdout, stderr)
					if code ~= 0 then
						local err = stderr
						if not err or err == "" then
							err = stdout
						end
						error_handler.notify_error("Plot Viewer", string.format("%s: %s", error_handler.E_VIEWER_FAILED, err or ""))
					end
				end,
			})
		end
	end
end

function M.apply_output(plot_opts, image_path)
	apply_output(plot_opts, image_path)
end

local function default_on_success(job, image_path)
	cleanup_temp(job)
	apply_output(job.plot_opts, image_path)
end

local function default_on_error(job, err)
	cleanup_temp(job)

	local code = err and err.code
	local msg = err and err.message or ""
	local cancelled = err and err.cancelled
	local backend_error_code = err and err.backend_error_code
	local error_code
	if cancelled or code == -1 then
		error_code = error_handler.E_CANCELLED
	elseif code == 127 then
		error_code = error_handler.E_BACKEND_UNAVAILABLE
	elseif code == 124 or msg:lower():find("timeout") then
		error_code = error_handler.E_TIMEOUT
	elseif backend_error_code then
		error_handler.notify_error("TungstenPlot", backend_error_code)
		return
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
	info.started_at = os.time()
	info.plot_opts = job.plot_opts

	local bufnr = job.plot_opts.bufnr or vim.api.nvim_get_current_buf()
	local row = job.plot_opts.end_line or job.plot_opts.start_line or 0
	local col = job.plot_opts.end_col or job.plot_opts.start_col or 0
	local frame_index = 1
	local extmark_id = vim.api.nvim_buf_set_extmark(bufnr, spinner_ns, row, col, {
		virt_text = { { spinner_frames[frame_index] } },
		virt_text_pos = "overlay",
	})
	info.extmark_id = extmark_id
	info.bufnr = bufnr
	info.expression = job.plot_opts.expression
	info.backend = job.plot_opts.backend
	active_plot_jobs[job.id] = info

	local timer = vim.loop.new_timer()
	if timer then
		local function update_spinner()
			frame_index = frame_index % #spinner_frames + 1
			local next_frame = spinner_frames[frame_index]
			vim.schedule(function()
				if info.extmark_id then
					pcall(vim.api.nvim_buf_set_extmark, info.bufnr, spinner_ns, row, col, {
						id = info.extmark_id,
						virt_text = { { next_frame } },
						virt_text_pos = "overlay",
					})
				end
			end)
		end

		timer:start(spinner_interval, spinner_interval, update_spinner)
		info.timer = timer
	end

	local handle = async.run_job(job.plot_opts, {
		on_exit = function(code, stdout, stderr)
			local function handle()
				if info.timer then
					info.timer:stop()
					info.timer:close()
					info.timer = nil
				end
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
						local stdout_text = stdout or ""
						local stderr_text = stderr or ""
						local msg = stderr_text ~= "" and stderr_text or stdout_text
						if msg == "" then
							msg = string.format("Process exited with code %d", code)
						end
						local translated
						local translator = job.plot_opts and job.plot_opts._error_translator
						if type(translator) == "function" then
							local ok, res = pcall(translator, code, stdout_text, stderr_text)
							if ok and type(res) == "table" then
								translated = res
							end
						end
						if translated and translated.message and translated.message ~= "" then
							msg = translated.message
						end
						local was_cancelled = (code == -1) or info.cancelled
						job.on_error({
							code = code,
							exit_code = code,
							message = msg,
							cancelled = was_cancelled,
							backend_error_code = translated and translated.code or nil,
						})
					end
				end
				_process_queue()
			end

			if vim.in_fast_event() then
				vim.schedule(handle)
			else
				handle()
			end
		end,
	})
	info.handle = handle
end

_process_queue = function()
	local configured_max = config.max_jobs or 3
	local max_jobs = math.min(configured_max, 3)
	while #job_queue > 0 and active_count() < max_jobs do
		local job = table.remove(job_queue, 1)
		active_plot_jobs[job.id] = { plot_opts = job.plot_opts }
		_execute_plot(job)
	end
end

function M.submit(plot_opts, user_on_success, user_on_error)
	plot_opts = plot_opts or {}
	local backend = plot_opts.backend or (config.plotting or {}).backend or "wolfram"

	local dep_vars = {}
	local has_points = false
	local has_inequality = false
	if plot_opts and plot_opts.series then
		for _, s in ipairs(plot_opts.series) do
			for _, v in ipairs(s.dependent_vars or {}) do
				dep_vars[#dep_vars + 1] = v
			end
			if s.kind == "points" then
				has_points = true
			elseif s.kind == "inequality" then
				has_inequality = true
			end
		end
	end
	plot_opts.has_points = has_points
	plot_opts.has_inequality = has_inequality

	local supported = true
	if plot_opts and plot_opts.form and plot_opts.dim then
		local backends = require("tungsten.domains.plotting.backends")
		supported = backends.is_supported(backend, plot_opts.form, plot_opts.dim, {
			dependent_vars = dep_vars,
			points = has_points,
			inequalities = has_inequality,
		})
	end

	if not supported then
		error_handler.notify_error("TungstenPlot", error_handler.E_UNSUPPORTED_FORM)
		return nil
	end

	if backend == "wolfram" then
		local wolfram_path = ((config.backend_opts or {}).wolfram or {}).wolfram_path or "wolframscript"
		if vim.fn.executable(wolfram_path) ~= 1 then
			error_handler.notify_error(
				"TungstenPlot",
				error_handler.E_BACKEND_UNAVAILABLE .. ": Install Wolfram or configure Python backend"
			)
			return nil
		end
	end

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

	if deps_ok == false then
		if missing_message then
			logger.error("TungstenPlot", missing_message)
		end
		error_handler.notify_error("TungstenPlot", error_handler.E_BACKEND_UNAVAILABLE, nil, missing_message)
		return nil
	end

	if deps_ok == nil then
		pending_dependency_jobs[job.id] = job
		on_dependencies_ready(function(ok, message)
			local pending_job = pending_dependency_jobs[job.id]
			if not pending_job then
				return
			end
			pending_dependency_jobs[job.id] = nil

			if not ok then
				cleanup_temp(pending_job)
				if message and not dependency_failure_notified then
					logger.error("TungstenPlot", message)
				end
				if not dependency_failure_notified then
					error_handler.notify_error("TungstenPlot", error_handler.E_BACKEND_UNAVAILABLE, nil, message)
					dependency_failure_notified = true
				end
				return
			end

			table.insert(job_queue, pending_job)
			_process_queue()
		end)
		return job.id
	end

	table.insert(job_queue, job)
	_process_queue()
	return job.id
end

function M.cancel(job_id)
	local info = active_plot_jobs[job_id]
	if info and info.handle and info.handle.cancel then
		info.cancelled = true
		info.handle.cancel()
		return true
	end

	for index, job in ipairs(job_queue) do
		if job.id == job_id then
			cleanup_temp(job)
			table.remove(job_queue, index)
			return true
		end
	end

	local pending_job = pending_dependency_jobs[job_id]
	if pending_job then
		cleanup_temp(pending_job)
		pending_dependency_jobs[job_id] = nil
		return true
	end
	return false
end

function M.cancel_all()
	for _, info in pairs(active_plot_jobs) do
		if info.handle and info.handle.cancel then
			info.cancelled = true
			info.handle.cancel()
		end
	end
	for _, job in ipairs(job_queue) do
		cleanup_temp(job)
	end
	job_queue = {}
end

M.active_jobs = active_plot_jobs
M._process_queue = _process_queue

function M.reset_deps_check()
	deps_ok = nil
	missing_message = nil
	dependency_waiters = {}
	dependency_check_in_flight = false
	pending_dependency_jobs = {}
	dependency_failure_notified = false
end

local function extract_ranges(plot_opts)
	if not plot_opts then
		return nil
	end
	local keys = {
		{ key = "xrange", label = "xrange" },
		{ key = "yrange", label = "yrange" },
		{ key = "zrange", label = "zrange" },
		{ key = "t_range", label = "t_range" },
		{ key = "u_range", label = "u_range" },
		{ key = "v_range", label = "v_range" },
		{ key = "theta_range", label = "theta_range" },
	}
	local ranges
	for _, entry in ipairs(keys) do
		local value = plot_opts[entry.key]
		if value ~= nil then
			ranges = ranges or {}
			ranges[entry.key] = vim.deepcopy(value)
		end
	end
	return ranges
end

function M.get_queue_snapshot()
	local snapshot = { active = {}, pending = {} }
	local now = vim.loop.now()

	for id, info in pairs(active_plot_jobs) do
		local plot_opts = info.plot_opts or {}
		local entry = {
			id = id,
			backend = plot_opts.backend,
			dim = plot_opts.dim,
			form = plot_opts.form,
			expression = plot_opts.expression,
			ranges = extract_ranges(plot_opts),
			out_path = plot_opts.out_path,
			started_at = info.started_at,
		}
		if info.start_time then
			entry.elapsed = math.max(0, now - info.start_time) / 1000
		end
		snapshot.active[#snapshot.active + 1] = entry
	end

	table.sort(snapshot.active, function(a, b)
		return (a.id or 0) < (b.id or 0)
	end)

	for _, job in ipairs(job_queue) do
		local plot_opts = job.plot_opts or {}
		snapshot.pending[#snapshot.pending + 1] = {
			id = job.id,
			backend = plot_opts.backend,
			dim = plot_opts.dim,
			form = plot_opts.form,
			expression = plot_opts.expression,
			ranges = extract_ranges(plot_opts),
			out_path = plot_opts.out_path,
		}
	end

	return snapshot
end

return M
