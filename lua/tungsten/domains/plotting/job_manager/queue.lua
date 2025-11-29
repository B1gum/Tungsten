local config = require("tungsten.config")
local logger = require("tungsten.util.logger")
local async = require("tungsten.util.async")
local path = require("pl.path")
local error_handler = require("tungsten.util.error_handler")
local plotting_errors = require("tungsten.domains.plotting.errors")
local plotting_io = require("tungsten.util.plotting_io")

local cleanup = require("tungsten.domains.plotting.job_manager.cleanup")
local dependencies = require("tungsten.domains.plotting.job_manager.dependencies")
local spinner = require("tungsten.domains.plotting.job_manager.spinner")

local M = {}

local job_queue = {}
local active_plot_jobs = {}
local pending_dependency_jobs = {}
local next_id = 0

local function clear_table(tbl)
	for k in pairs(tbl) do
		tbl[k] = nil
	end
end

local function active_count()
	local n = 0
	for _ in pairs(active_plot_jobs) do
		n = n + 1
	end
	return n
end

local function sanitize_path(path_str)
	if type(path_str) ~= "string" then
		return path_str
	end
	local cleaned = path_str:gsub("\r", "")
	cleaned = cleaned:gsub("\n", "")
	cleaned = cleaned:gsub("^%s+", "")
	cleaned = cleaned:gsub("%s+$", "")
	return cleaned
end

local function apply_output(plot_opts, image_path)
	if not plot_opts then
		return
	end

	if (not image_path or image_path == "") and plot_opts.out_path and plot_opts.out_path ~= "" then
		image_path = plot_opts.out_path
	end
	image_path = sanitize_path(image_path)
	if not image_path or image_path == "" then
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
						if err and err ~= "" then
							error_handler.notify_error("Plot Viewer", error_handler.E_VIEWER_FAILED, nil, nil, err)
						else
							error_handler.notify_error("Plot Viewer", error_handler.E_VIEWER_FAILED)
						end
					end
				end,
			})
		end
	end
end

function M.apply_output(plot_opts, image_path)
	apply_output(plot_opts, image_path)
end

local function augment_plot_opts(plot_opts)
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

	return dep_vars, has_points, has_inequality
end

local function default_on_success(job, image_path)
	cleanup.cleanup_temp(job)
	apply_output(job.plot_opts, image_path)
end

local function default_on_error(job, err)
	cleanup.cleanup_temp(job, true)

	local error_code, message_suffix, backend_error_code = plotting_errors.normalize_job_error(err)

	if backend_error_code then
		if message_suffix then
			error_handler.notify_error("TungstenPlot", backend_error_code, nil, nil, message_suffix)
		else
			error_handler.notify_error("TungstenPlot", backend_error_code)
		end
		return
	end

	if message_suffix then
		error_handler.notify_error("TungstenPlot", error_code, nil, nil, message_suffix)
	else
		error_handler.notify_error("TungstenPlot", error_code)
	end
end

local function prepare_cursor_location(plot_opts)
	local bufnr = plot_opts.bufnr or vim.api.nvim_get_current_buf()
	local row = plot_opts.end_line or plot_opts.start_line or 0
	local col = plot_opts.end_col or plot_opts.start_col or 0

	local line_count = vim.api.nvim_buf_line_count(bufnr)
	if line_count < 1 then
		line_count = 1
	end
	if row < 0 then
		row = 0
	elseif row > line_count then
		row = line_count
	end
	if row == line_count then
		col = 0
	else
		local line_text = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
		local max_col = #line_text
		if col < 0 then
			col = 0
		elseif col > max_col then
			col = max_col
		end
	end

	return bufnr, row, col
end

local _process_queue

local function handle_job_exit(job, info, code, stdout, stderr)
	if info.timer then
		info.timer:stop()
		info.timer:close()
		info.timer = nil
	end
	if info.extmark_id then
		pcall(vim.api.nvim_buf_del_extmark, info.bufnr, info.spinner_ns, info.extmark_id)
	end
	active_plot_jobs[job.id] = nil

	if code == 0 then
		local trimmed = stdout
		if type(trimmed) == "string" then
			trimmed = trimmed:match("^%s*(.-)%s*$")
			if trimmed == "" then
				trimmed = nil
			end
		end
		if job.on_success then
			job.on_success(trimmed)
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

	local bufnr, row, col = prepare_cursor_location(job.plot_opts)
	info.bufnr = bufnr
	info.expression = job.plot_opts.expression
	info.backend = job.plot_opts.backend
	active_plot_jobs[job.id] = info

	local extmark_id, timer, spinner_ns = spinner.start_spinner(bufnr, row, col)
	info.extmark_id = extmark_id
	info.timer = timer
	info.spinner_ns = spinner_ns

	local handle = async.run_job(job.plot_opts, {
		on_exit = function(code, stdout, stderr)
			local function handle()
				handle_job_exit(job, info, code, stdout, stderr)
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

local function validate_backend_support(plot_opts, backend, dep_vars, has_points, has_inequality)
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
		return false
	end

	if backend == "wolfram" then
		local wolfram_path = ((config.backend_opts or {}).wolfram or {}).wolfram_path or "wolframscript"
		if vim.fn.executable(wolfram_path) ~= 1 then
			error_handler.notify_error(
				"TungstenPlot",
				error_handler.E_BACKEND_UNAVAILABLE,
				nil,
				nil,
				"Install Wolfram or configure Python backend"
			)
			return false
		end
	end

	return true
end

local function prepare_job_callbacks(job, user_on_success, user_on_error)
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
end

local function ensure_backend_dependencies_ok(backend, job)
	local backend_ok, backend_message = dependencies.get_backend_status(backend)
	if backend_ok then
		return true
	end

	if job then
		cleanup.cleanup_temp(job, true)
	end
	dependencies.notify_backend_failure(backend, backend_message)
	return false
end

local function enqueue_job(job, backend)
	if dependencies.has_dependency_report() then
		if not ensure_backend_dependencies_ok(backend, job) then
			return false
		end

		table.insert(job_queue, job)
		_process_queue()
		return true
	end

	pending_dependency_jobs[job.id] = job
	dependencies.on_dependencies_ready(function()
		local pending_job = pending_dependency_jobs[job.id]
		if not pending_job then
			return
		end
		pending_dependency_jobs[job.id] = nil

		local job_backend = pending_job.plot_opts.backend or (config.plotting or {}).backend or "wolfram"
		if not ensure_backend_dependencies_ok(job_backend, pending_job) then
			return
		end

		table.insert(job_queue, pending_job)
		_process_queue()
	end)

	return true
end

function M.submit(plot_opts, user_on_success, user_on_error)
	plot_opts = plot_opts or {}
	local backend = plot_opts.backend or (config.plotting or {}).backend or "wolfram"

	local dep_vars, has_points, has_inequality = augment_plot_opts(plot_opts)
	if not validate_backend_support(plot_opts, backend, dep_vars, has_points, has_inequality) then
		return nil
	end

	next_id = next_id + 1
	local job = { id = next_id, plot_opts = plot_opts }

	prepare_job_callbacks(job, user_on_success, user_on_error)

	if not enqueue_job(job, backend) then
		return nil
	end

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
			table.remove(job_queue, index)
			cleanup.notify_job_cancelled(job)
			return true
		end
	end

	local pending_job = pending_dependency_jobs[job_id]
	if pending_job then
		pending_dependency_jobs[job_id] = nil
		cleanup.notify_job_cancelled(pending_job)
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
		cleanup.notify_job_cancelled(job)
	end
	job_queue = {}

	for job_id, job in pairs(pending_dependency_jobs) do
		pending_dependency_jobs[job_id] = nil
		cleanup.notify_job_cancelled(job)
	end
	clear_table(pending_dependency_jobs)
end

function M.reset_state()
	clear_table(job_queue)
	clear_table(active_plot_jobs)
	clear_table(pending_dependency_jobs)
	next_id = 0
end

function M.reset_dependencies()
	clear_table(pending_dependency_jobs)
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

M.active_jobs = active_plot_jobs
M._process_queue = _process_queue

return M
