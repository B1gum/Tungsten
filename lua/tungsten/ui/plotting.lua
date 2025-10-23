local core = require("tungsten.core.plotting")
local error_handler = require("tungsten.util.error_handler")
local state = require("tungsten.state")
local config = require("tungsten.config")
local async = require("tungsten.util.async")
local io_util = require("tungsten.util.io")

local M = {}

local function extract_series_label(entry)
	if type(entry) == "table" then
		return entry.ast
			or entry.value
			or entry.display
			or entry.text
			or entry.raw
			or entry.source
			or entry.name
			or entry.label
			or entry.type
	end
	if entry == nil then
		return ""
	end
	return tostring(entry)
end

local function resolve_series_entries(opts)
	opts = opts or {}
	local classification_series = (opts.classification and opts.classification.series) or {}
	local series = opts.series or classification_series or {}
	series = vim.deepcopy(series)
	local parsed_series = opts.parsed_series or {}
	local max_count = math.max(#series, #parsed_series)
	for i = 1, max_count do
		series[i] = series[i] or {}
		local parsed_entry = parsed_series[i]
		if parsed_entry and (series[i].ast == nil or series[i].ast == "") then
			series[i].ast = extract_series_label(parsed_entry)
		end
	end
	return series
end

local function parse_style_tokens(tokens)
	local res = {}
	if type(tokens) == "string" then
		tokens = vim.split(tokens, " ", { trimempty = true })
	end
	if type(tokens) ~= "table" then
		return res
	end
	for _, tok in ipairs(tokens) do
		local key, val = tok:match("^%s*(%w+)%s*=%s*(.-)%s*$")
		if key and val then
			val = val:gsub("^['\"]", ""):gsub("['\"]$", "")
			local num = tonumber(val)
			res[key] = num or val
		end
	end
	return res
end

local function parse_definitions(input)
	local defs = {}
	if not input or input == "" then
		return defs
	end
	for line in input:gmatch("[^\n]+") do
		local lhs, rhs = line:match("^%s*(.-)%s*:?=%s*(.-)%s*$")
		if lhs and rhs and lhs ~= "" and rhs ~= "" then
			defs[lhs] = { latex = rhs }
		end
	end
	return defs
end

function M.handle_undefined_symbols(opts, callback)
	opts = opts or {}
	local definitions = {}
	for name, val in pairs(state.persistent_variables or {}) do
		definitions[name] = { latex = val }
	end

	local _, undefined = core.get_undefined_symbols(opts)
	undefined = undefined or {}
	local to_define = {}
	for _, sym in ipairs(undefined) do
		if not definitions[sym.name] then
			table.insert(to_define, sym)
		end
	end

	if #to_define == 0 then
		if next(opts) ~= nil then
			opts.definitions = definitions
			if callback then
				callback(opts)
			end
		else
			if callback then
				callback(definitions)
			end
		end
		return
	end

	local lines = {}
	for _, sym in ipairs(to_define) do
		lines[#lines + 1] = sym.name .. " = "
	end
	local default = table.concat(lines, "\n")

	vim.ui.input({ prompt = "Define symbols for plot:", default = default }, function(user_input)
		local parsed = parse_definitions(user_input)
		for name, def in pairs(parsed) do
			definitions[name] = def
		end
		if next(opts) ~= nil then
			opts.definitions = definitions
			if callback then
				callback(opts)
			end
		else
			if callback then
				callback(definitions)
			end
		end
	end)
end

function M.start_plot_workflow(opts)
	opts = opts or {}
	M.handle_undefined_symbols(opts, function(final_opts)
		final_opts.on_error = function(code, msg)
			error_handler.notify_error("Plot Error", string.format("%s: %s", code, msg))
		end
		core.initiate_plot(final_opts)
	end)
end

function M.insert_snippet(bufnr, selection_end_line, plot_path)
	local width = (config.plotting or {}).snippet_width or "0.8\\linewidth"
	local _, line = io_util.find_math_block_end(bufnr, selection_end_line)
	line = line or selection_end_line
	local snippet = string.format("\\includegraphics[width=%s]{%s}", width, plot_path)
	vim.api.nvim_buf_set_lines(bufnr, line, line, false, { snippet })
end

function M.handle_output(plot_path)
	local cfg = config.plotting or {}
	if cfg.outputmode ~= nil and cfg.outputmode ~= "viewer" then
		return
	end
	local cmd
	if plot_path:match("%.pdf$") then
		cmd = cfg.viewer_cmd_pdf
	else
		cmd = cfg.viewer_cmd_png
	end
	if not cmd or cmd == "" then
		cmd = "open"
	end
	async.run_job({ cmd, plot_path }, {
		on_exit = function(code, _out, err)
			if code ~= 0 then
				error_handler.notify_error("Plot Viewer", "E_VIEWER_FAILED: " .. (err or ""))
			end
		end,
	})
end

local function format_range(range)
	if type(range) ~= "table" then
		return ""
	end
	local start_val = range[1] ~= nil and tostring(range[1]) or ""
	local end_val = range[2] ~= nil and tostring(range[2]) or ""
	return string.format("[%s, %s]", start_val, end_val)
end

local function to_on_off(val)
	if val == nil then
		return "auto"
	end
	return val and "on" or "off"
end

local function determine_legend_auto(opts, classification, series)
	if opts.legend_auto ~= nil then
		return opts.legend_auto
	end
	if classification.legend_auto ~= nil then
		return classification.legend_auto
	end
	local count = #series
	if count > 1 then
		return true
	elseif count == 1 then
		local lbl = series[1].label
		return lbl ~= nil and lbl ~= ""
	end
	return false
end

local function collect_dependents(series, dim, form)
	local set = {}
	for _, s in ipairs(series) do
		for _, dep in ipairs(s.dependent_vars or {}) do
			set[dep] = true
		end
	end
	if next(set) == nil then
		if dim == 2 and form == "explicit" then
			set.y = true
		elseif dim == 3 and (form == "explicit" or form == "implicit") then
			set.z = true
		elseif form == "polar" then
			set.r = true
		elseif form == "parametric" then
			if dim == 2 then
				set.x = true
				set.y = true
			elseif dim == 3 then
				set.x = true
				set.y = true
				set.z = true
			end
		end
	end
	local ordered = {}
	local priority = { x = 1, y = 2, z = 3, r = 4, theta = 5, u = 6, v = 7, t = 8 }
	for key in pairs(set) do
		table.insert(ordered, key)
	end
	table.sort(ordered, function(a, b)
		local pa = priority[a] or 99
		local pb = priority[b] or 99
		if pa == pb then
			return a < b
		end
		return pa < pb
	end)
	if #ordered == 0 then
		return "auto"
	end
	return table.concat(ordered, ", ")
end

local function get_series_defaults(series)
	local parsed = parse_style_tokens(series.style_tokens or series.style)
	return {
		color = series.color or parsed.color or "auto",
		linewidth = series.linewidth or parsed.linewidth or "1.5",
		linestyle = series.linestyle or parsed.linestyle or "solid",
		marker = series.marker or parsed.marker or "none",
		markersize = series.markersize or parsed.markersize or "6",
		alpha = series.alpha or parsed.alpha or "1.0",
	}
end

local function build_default_lines(opts)
	opts = opts or {}
	local defaults = config.plotting or {}
	local classification = opts.classification or {}
	local form = classification.form or opts.form or "explicit"
	local dim = classification.dim or opts.dim or 2
	local backend = opts.backend or defaults.backend or "wolfram"
	local outputmode = opts.outputmode or defaults.outputmode or "latex"
	local aspect
	if opts.aspect then
		aspect = opts.aspect
	elseif dim == 2 and form == "explicit" then
		aspect = "auto"
	else
		aspect = "equal"
	end
	local series = {}
	if type(opts.series) == "table" and #opts.series > 0 then
		series = opts.series
	elseif type(classification.series) == "table" and #classification.series > 0 then
		series = classification.series
	end
	local legend_auto = determine_legend_auto(opts, classification, series)
	local legend_state = legend_auto and "auto" or "off"
	local legend_placement = opts.legend_placement or opts.legend_position or "best"
	local dependents = collect_dependents(series, dim, form)
	local lines = {}
	lines[#lines + 1] = "Form: " .. form
	lines[#lines + 1] = "Backend: " .. backend
	lines[#lines + 1] = "Output mode: " .. outputmode
	lines[#lines + 1] = "Aspect: " .. aspect
	lines[#lines + 1] = "Legend: " .. legend_state
	lines[#lines + 1] = "Legend placement: " .. legend_placement
	lines[#lines + 1] = "Dependents: " .. dependents
	lines[#lines + 1] = ""
	if dim >= 1 then
		local xrange = opts.xrange or defaults.default_xrange
		lines[#lines + 1] = "X-range: " .. format_range(xrange)
	end
	if dim >= 2 then
		local yrange = opts.yrange or defaults.default_yrange
		lines[#lines + 1] = "Y-range: " .. format_range(yrange)
	end
	if dim >= 3 then
		local zrange = opts.zrange or defaults.default_zrange
		lines[#lines + 1] = "Z-range: " .. format_range(zrange)
	end
	if form == "parametric" and dim == 2 then
		local trange = opts.t_range or defaults.default_t_range
		lines[#lines + 1] = "T-range: " .. format_range(trange)
	elseif form == "parametric" and dim == 3 then
		local urange = opts.u_range or defaults.default_urange
		local vrange = opts.v_range or defaults.default_vrange
		lines[#lines + 1] = "U-range: " .. format_range(urange)
		lines[#lines + 1] = "V-range: " .. format_range(vrange)
	elseif form == "polar" then
		local theta_range = opts.theta_range or defaults.default_theta_range
		lines[#lines + 1] = "Theta-range: " .. format_range(theta_range)
	end
	local grid_val = opts.grid
	if grid_val == nil then
		grid_val = opts.grids
	end
	if grid_val == nil then
		grid_val = true
	end
	lines[#lines + 1] = "Grid: " .. to_on_off(grid_val)
	if dim >= 1 then
		lines[#lines + 1] = "X-scale: " .. (opts.xscale or "linear")
	end
	if dim >= 2 then
		lines[#lines + 1] = "Y-scale: " .. (opts.yscale or "linear")
	end
	if dim >= 3 then
		lines[#lines + 1] = "Z-scale: " .. (opts.zscale or "linear")
	end
	if dim == 3 then
		lines[#lines + 1] = "View elevation: " .. tostring(opts.view_elev or 30)
		lines[#lines + 1] = "View azimuth: " .. tostring(opts.view_azim or -60)
	end
	lines[#lines + 1] = "Colormap: " .. tostring(opts.colormap or "viridis")
	lines[#lines + 1] = "Colorbar: " .. (opts.colorbar == nil and "off" or to_on_off(opts.colorbar))
	lines[#lines + 1] = "Background: " .. tostring(opts.bg_color or "white")
	lines[#lines + 1] = ""
	for i, s in ipairs(series) do
		local defaults_for_series = get_series_defaults(s)
		lines[#lines + 1] = string.format("--- Series %d: %s ---", i, s.ast or "")
		lines[#lines + 1] = "Label: " .. (s.label or "")
		lines[#lines + 1] = "Dependents: " .. collect_dependents({ s }, dim, form)
		lines[#lines + 1] = "Color: " .. tostring(defaults_for_series.color)
		lines[#lines + 1] = "Linewidth: " .. tostring(defaults_for_series.linewidth)
		lines[#lines + 1] = "Linestyle: " .. tostring(defaults_for_series.linestyle)
		lines[#lines + 1] = "Marker: " .. tostring(defaults_for_series.marker)
		lines[#lines + 1] = "Markersize: " .. tostring(defaults_for_series.markersize)
		lines[#lines + 1] = "Alpha: " .. tostring(defaults_for_series.alpha)
		if i < #series then
			lines[#lines + 1] = ""
		end
	end
	return lines
end

function M.open_advanced_config(opts)
	opts = opts or {}
	local bufnr = vim.api.nvim_create_buf(false, true)
	local lines = build_default_lines(opts)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.api.nvim_open_win(bufnr, true, { relative = "editor", width = 60, height = #lines, row = 1, col = 1 })
	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = bufnr,
		callback = function()
			vim.ui.input({ prompt = "Generate plot with current configuration? (y/N): " }, function(answer)
				if answer and answer:match("^%s*[Yy]") then
					core.initiate_plot(opts)
				end
			end)
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", { buffer = bufnr, callback = function() end })
end

function M.build_final_opts_from_classification(classification)
	local final = vim.deepcopy(classification or {})
	final.series = {}
	local src_series = (classification and classification.series) or {}
	local multi = #src_series > 1
	for i, s in ipairs(src_series) do
		final.series[i] = vim.deepcopy(s)
		if multi and (not final.series[i].label or final.series[i].label == "") then
			final.series[i].label = string.format("Series %d", i)
		end
		local style = parse_style_tokens(s.style_tokens or s.style)
		for k, v in pairs(style) do
			final.series[i][k] = v
		end
	end
	if #final.series > 1 then
		final.legend_auto = true
	elseif #final.series == 1 then
		local lbl = final.series[1].label
		final.legend_auto = lbl ~= nil and lbl ~= ""
	else
		final.legend_auto = false
	end
	return final
end

return M
