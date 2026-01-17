local job_reporter = require("tungsten.core.job_reporter")

local M = {}

local function open_float(lines, opts)
	opts = opts or {}
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local width = 0
	for _, line in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(line))
	end

	local min_width = opts.min_width or 20
	local max_width = opts.max_width or (vim.o.columns - 4)
	width = math.max(min_width, math.min(width, math.max(20, max_width)))

	local height = #lines
	local max_height = opts.max_height or math.max(1, math.floor(vim.o.lines * 0.7))
	height = math.max(1, math.min(height, max_height))

	local opts_win = {
		relative = "editor",
		style = "minimal",
		border = "rounded",
		width = width,
		height = height,
		row = math.max(0, math.floor((vim.o.lines - height) / 2)),
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
	}

	local win = vim.api.nvim_open_win(buf, true, opts_win)
	return { win_id = win, buf_id = buf }
end

local function truncate(text, max_len)
	if not text or max_len == nil then
		return text
	end
	text = tostring(text)
	if #text <= max_len then
		return text
	end
	if max_len <= 1 then
		return text:sub(1, max_len)
	end
	return text:sub(1, max_len - 1) .. "…"
end

local function format_ranges(ranges)
	if not ranges then
		return "--"
	end
	local ordered = {
		{ key = "xrange", label = "x" },
		{ key = "yrange", label = "y" },
		{ key = "zrange", label = "z" },
		{ key = "t_range", label = "t" },
		{ key = "u_range", label = "u" },
		{ key = "v_range", label = "v" },
		{ key = "theta_range", label = "θ" },
	}
	local parts = {}
	for _, def in ipairs(ordered) do
		local value = ranges[def.key]
		if value ~= nil then
			if type(value) == "table" then
				local pieces = {}
				for i, v in ipairs(value) do
					pieces[i] = tostring(v)
				end
				value = string.format("[%s]", table.concat(pieces, ", "))
			else
				value = tostring(value)
			end
			parts[#parts + 1] = string.format("%s: %s", def.label, value)
		end
	end
	if #parts == 0 then
		return "--"
	end
	return table.concat(parts, "; ")
end

local function build_queue_lines(snapshot)
	local lines = {}
	snapshot = snapshot or { active = {}, pending = {} }

	local entries = {}
	for _, entry in ipairs(snapshot.active or {}) do
		entries[#entries + 1] = vim.deepcopy(entry)
		entries[#entries].state = "active"
	end
	for _, entry in ipairs(snapshot.pending or {}) do
		entries[#entries + 1] = vim.deepcopy(entry)
		entries[#entries].state = "pending"
	end

	if #entries == 0 then
		return { "No active or pending plot jobs." }
	end

	local header = string.format(
		"%-4s %-8s %-9s %-12s %-28s %-30s %-10s %-8s %s",
		"ID",
		"State",
		"Backend",
		"Dim/Form",
		"Expression",
		"Ranges",
		"Started",
		"Elapsed",
		"Output"
	)

	lines[#lines + 1] = "Tungsten Plot Queue"
	lines[#lines + 1] = string.rep("─", math.max(20, #header))
	lines[#lines + 1] = header
	lines[#lines + 1] = string.rep("─", math.max(20, #header))

	local function format_dim_form(entry)
		if entry.dim and entry.form then
			return string.format("%sD %s", entry.dim, entry.form)
		elseif entry.dim then
			return string.format("%sD", entry.dim)
		end
		return entry.form or "--"
	end

	for _, entry in ipairs(entries) do
		local expression = entry.expression or "--"
		local ranges = format_ranges(entry.ranges)
		local started
		if entry.started_at then
			started = os.date("%H:%M:%S", entry.started_at)
		else
			started = "--"
		end
		local elapsed = entry.elapsed and string.format("%.1fs", entry.elapsed) or "--"

		local row = string.format(
			"%-4s %-8s %-9s %-12s %-28s %-30s %-10s %-8s %s",
			entry.id or "--",
			entry.state,
			entry.backend or "--",
			truncate(format_dim_form(entry), 12),
			truncate(expression, 28),
			truncate(ranges, 30),
			started,
			elapsed,
			truncate(entry.out_path or "--", 40)
		)
		lines[#lines + 1] = row
	end

	return lines
end

function M.open(summary)
	summary = summary or job_reporter.get_active_jobs_summary()
	local lines = vim.split(summary, "\n")
	if #lines == 0 then
		lines = { "" }
	end
	return open_float(lines, {})
end

function M.open_queue(snapshot)
	local lines = build_queue_lines(snapshot)
	return open_float(lines, { min_width = 60, max_height = math.floor(vim.o.lines * 0.6) })
end

return M
