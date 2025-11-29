local core = require("tungsten.core.plotting")
local error_handler = require("tungsten.util.error_handler")
local state = require("tungsten.state")
local config = require("tungsten.config")
local async = require("tungsten.util.async")
local io_util = require("tungsten.ui.io")
local options_builder = require("tungsten.domains.plotting.options_builder")
local style_parser = require("tungsten.domains.plotting.style_parser")
local parser = require("tungsten.core.parser")
local evaluator = require("tungsten.core.engine")
local backend_manager = require("tungsten.backends.manager")

local M = {}

local missing_math_block_warning_shown = false

local function warn_missing_math_block_end()
	if missing_math_block_warning_shown then
		return
	end
	missing_math_block_warning_shown = true
	local message =
		"Tungsten[plotting] Could not find a closing math delimiter; inserting snippet after the current selection."
	if vim and vim.notify_once then
		vim.notify_once(message, vim.log.levels.WARN)
	elseif vim and vim.notify then
		vim.notify(message, vim.log.levels.WARN)
	end
end

local DEPENDENTS_HINT = " (blank or auto to recompute)"

local function strip_dependents_hint(value)
	if type(value) ~= "string" or value == "" then
		return value
	end
	if value:sub(-#DEPENDENTS_HINT) == DEPENDENTS_HINT then
		local stripped = value:sub(1, #value - #DEPENDENTS_HINT)
		return vim.trim(stripped)
	end
	return value
end

local function parse_definitions(input)
	local defs = {}
	local order
	if not input or input == "" then
		return defs
	end
	for line in input:gmatch("[^\n]+") do
		local lhs, rhs = line:match("^%s*(.-)%s*:?=%s*(.-)%s*$")
		if lhs and rhs and lhs ~= "" and rhs ~= "" then
			order = order or {}
			order[#order + 1] = lhs
			defs[lhs] = { latex = rhs }
		end
	end
	if order and #order > 0 then
		defs.__order = order
	end
	return defs
end

local function parse_numeric_result(result)
	if type(result) == "number" then
		return result
	end
	if type(result) ~= "string" then
		return nil
	end
	local trimmed = vim.trim(result)
	if trimmed == "" then
		return nil
	end
	trimmed = trimmed:gsub("\\,", "")
	trimmed = trimmed:gsub("\\!", "")
	trimmed = trimmed:gsub("\\;", "")
	trimmed = trimmed:gsub("%s+", "")
	local numeric = tonumber(trimmed)
	if numeric then
		return numeric
	end
	local tuple_body = trimmed:match("^\\left%((.+)\\right%)$") or trimmed:match("^%((.+)%)$")
	if tuple_body then
		local components = vim.split(tuple_body, ",", { plain = true, trimempty = false })
		if #components == 3 then
			local tuple = {}
			for _, component in ipairs(components) do
				if component == nil or component == "" then
					return nil
				end
				local value = parse_numeric_result(component)
				if type(value) ~= "number" then
					return nil
				end
				table.insert(tuple, value)
			end
			return tuple
		else
			return nil
		end
	end
	local mantissa, exponent = trimmed:match("^([%+%-]?[%d%.]+)\\times10%^{([%+%-]?%d+)}$")
	if not mantissa then
		mantissa, exponent = trimmed:match("^([%+%-]?[%d%.]+)\\cdot10%^{([%+%-]?%d+)}$")
	end
	if not mantissa then
		mantissa, exponent = trimmed:match("^([%+%-]?[%d%.]+)\\cdot10%^{([%+%-]?%d+)}$")
	end
	if not mantissa then
		mantissa, exponent = trimmed:match("^([%+%-]?[%d%.]+)10%^{([%+%-]?%d+)}$")
	end
	if mantissa and exponent then
		local base_val = tonumber(mantissa)
		local exp_val = tonumber(exponent)
		if base_val and exp_val then
			return base_val * (10 ^ exp_val)
		end
	end
	local power_only = trimmed:match("^10%^{([%+%-]?%d+)}$")
	if power_only then
		local exp_only_val = tonumber(power_only)
		if exp_only_val then
			return 10 ^ exp_only_val
		end
	end
	return nil
end

local function evaluate_definition(name, entry, handler)
	entry = entry or {}
	local latex = entry.latex
	if not latex or vim.trim(latex) == "" then
		handler(false, error_handler.E_BAD_OPTS, string.format("Definition for '%s' cannot be empty.", tostring(name)))
		return
	end
	local ok, parsed_or_err = pcall(parser.parse, latex, { simple_mode = true })
	if not ok or not parsed_or_err then
		handler(
			false,
			error_handler.E_BAD_OPTS,
			string.format("Failed to parse definition for '%s': %s", tostring(name), tostring(parsed_or_err))
		)
		return
	end
	if not parsed_or_err.series or #parsed_or_err.series ~= 1 then
		handler(false, error_handler.E_BAD_OPTS, string.format("Definition for '%s' must be a single expression.", name))
		return
	end
	evaluator.evaluate_async(parsed_or_err.series[1], true, function(result, err)
		if err or not result then
			handler(
				false,
				error_handler.E_BAD_OPTS,
				string.format("Failed to evaluate '%s': %s", tostring(name), tostring(err or "Unknown error"))
			)
			return
		end
		local numeric_value = parse_numeric_result(result)
		local requires_point3 = entry.requires_point3
		if requires_point3 then
			if type(numeric_value) ~= "table" then
				handler(false, error_handler.E_BAD_OPTS, "3D points must be (x,y,z)")
				return
			end
			if #numeric_value ~= 3 then
				handler(false, error_handler.E_BAD_OPTS, "3D points must be (x,y,z)")
				return
			end
			for _, component in ipairs(numeric_value) do
				if type(component) ~= "number" then
					handler(false, error_handler.E_BAD_OPTS, "3D points must be (x,y,z)")
					return
				end
			end
			handler(true, numeric_value)
			return
		end
		if type(numeric_value) ~= "number" then
			handler(false, error_handler.E_BAD_OPTS, string.format("Could not evaluate '%s' to a real number.", name))
			return
		end
		handler(true, numeric_value)
	end)
end

local function evaluate_definitions(defs, on_success, on_failure)
	if not defs or vim.tbl_isempty(defs) then
		if on_success then
			on_success()
		end
		return
	end
	if not backend_manager.current() then
		if on_failure then
			on_failure(error_handler.E_BACKEND_UNAVAILABLE, "No active backend available for evaluating definitions.")
		end
		return
	end
	local names = {}
	local seen = {}
	local order = defs.__order
	if type(order) == "table" and #order > 0 then
		for _, name in ipairs(order) do
			if name ~= "__order" and defs[name] and not seen[name] then
				seen[name] = true
				names[#names + 1] = name
			end
		end
	end
	for name in pairs(defs) do
		if name ~= "__order" and not seen[name] then
			seen[name] = true
			names[#names + 1] = name
		end
	end
	if #names == 0 then
		if on_success then
			on_success()
		end
		return
	end
	local evaluated = {}
	local function handle_failure(code, message)
		if on_failure then
			on_failure(code, message)
		end
	end
	local function step(index)
		if index > #names then
			if on_success then
				on_success()
			end
			return
		end
		local name = names[index]
		local entry = defs[name]
		evaluate_definition(name, entry, function(ok, value_or_code, err_msg)
			if not ok then
				local dependency_symbol
				if type(err_msg) == "string" and err_msg:lower():find("unknown symbol", 1, true) then
					dependency_symbol = err_msg:match("[Uu]nknown%s+[Ss]ymbol[:%s']+([%w_]+)")
					if not dependency_symbol then
						dependency_symbol = err_msg:match("[Uu]nknown%s+[Ss]ymbol[^%w]+([%w_]+)")
					end
				end
				if dependency_symbol and defs[dependency_symbol] and not evaluated[dependency_symbol] then
					local msg = string.format(
						"Definition '%s' depends on '%s', which has not been defined yet. Reorder or simplify your definitions.",
						name,
						dependency_symbol
					)
					handle_failure(error_handler.E_BAD_OPTS, msg)
					return
				end
				handle_failure(value_or_code, err_msg)
				return
			end
			entry.value = value_or_code
			evaluated[name] = true
			step(index + 1)
		end)
	end
	step(1)
end

local function normalize_buffer_lines(lines)
	local cleaned = {}
	for _, line in ipairs(lines or {}) do
		local trimmed = vim.trim(line)
		if trimmed ~= "" and not trimmed:match("^Variables:?$") and not trimmed:match("^Functions:?$") then
			if not trimmed:match(":?=") then
				local replaced, substitutions = trimmed:gsub(":%s*", ":=", 1)
				if substitutions == 0 then
					replaced = trimmed .. ":="
				end
				trimmed = replaced
			end
			table.insert(cleaned, trimmed)
		end
	end
	if #cleaned == 0 then
		return nil
	end
	return table.concat(cleaned, "\n")
end

local function populate_symbol_buffer(symbols)
	local seen = {}
	local variables, functions = {}, {}
	for _, sym in ipairs(symbols) do
		local name = sym.name
		if name and name ~= "" and not seen[name] then
			seen[name] = true
			if sym.type == "function" then
				table.insert(functions, name)
			else
				table.insert(variables, name)
			end
		end
	end

	local lines = {}
	if #variables > 0 then
		table.insert(lines, "Variables:")
		for _, name in ipairs(variables) do
			table.insert(lines, string.format("%s:", name))
		end
	end
	if #functions > 0 then
		if #lines > 0 then
			table.insert(lines, "")
		end
		table.insert(lines, "Functions:")
		for _, name in ipairs(functions) do
			table.insert(lines, string.format("%s:=", name))
		end
	end
	if #lines == 0 then
		lines = { "Variables:" }
	end
	return lines
end

local function symbol_requires_point3(sym)
	if type(sym) ~= "table" then
		return false
	end
	if sym.requires_point3 ~= nil then
		return sym.requires_point3
	end
	local symbol_type = sym.type or sym.kind or ""
	local dim = sym.point_dim or sym.dimension or sym.dim or sym.expected_dim
	if type(symbol_type) == "string" then
		local lowered = symbol_type:lower()
		if lowered == "point3" or lowered == "point_3d" or lowered == "point3d" then
			return true
		end
		if (lowered == "point" or lowered == "points" or lowered == "point_variable") and dim == 3 then
			return true
		end
		if lowered:find("point", 1, true) and dim == 3 then
			return true
		end
	end
	return false
end

function M.handle_undefined_symbols(opts, callback)
	opts = opts or {}
	local definitions = {}
	local point3_requirements = {}
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
		if sym.name and symbol_requires_point3(sym) then
			point3_requirements[sym.name] = true
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

	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(bufnr, "TungstenPlotDefinitions")
	local lines = populate_symbol_buffer(to_define)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(bufnr, "filetype", "tex")
	vim.api.nvim_buf_set_option(bufnr, "buftype", "acwrite")
	vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(bufnr, "swapfile", false)

	local width = 0
	for _, line in ipairs(lines) do
		width = math.max(width, #line)
	end
	width = math.max(width + 4, 40)
	local height = math.max(#lines, 3)
	vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		width = width,
		height = height,
		row = 1,
		col = 1,
		border = "rounded",
	})

	local resolved = false
	local function dispatch_definitions()
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
	end

	local function finalize_definitions()
		if resolved then
			return
		end
		resolved = true
		local buffer_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local normalized = normalize_buffer_lines(buffer_lines)
		local parsed
		if normalized then
			parsed = parse_definitions(normalized)
		end

		if parsed then
			for name, def in pairs(parsed) do
				if name ~= "__order" and point3_requirements[name] then
					def.requires_point3 = true
				end
			end
		end

		local function apply_and_dispatch()
			if parsed then
				for name, def in pairs(parsed) do
					if name ~= "__order" then
						definitions[name] = def
					end
				end
			end
			dispatch_definitions()
		end

		if parsed and not vim.tbl_isempty(parsed) then
			evaluate_definitions(parsed, function()
				apply_and_dispatch()
			end, function(err_code, err_message)
				error_handler.notify_error("Plot Definitions", err_code or error_handler.E_BAD_OPTS, nil, nil, err_message)
			end)
		else
			apply_and_dispatch()
		end
	end

	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = bufnr,
		once = true,
		callback = function()
			finalize_definitions()
			if vim.api.nvim_buf_is_valid(bufnr) then
				vim.api.nvim_buf_delete(bufnr, { force = true })
			end
		end,
	})

	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = bufnr,
		callback = finalize_definitions,
	})
end

function M.start_plot_workflow(opts)
	opts = opts or {}
	M.handle_undefined_symbols(opts, function(final_opts)
		final_opts.on_error = function(code, msg)
			local error_code = code or msg or error_handler.E_BACKEND_CRASH
			local message_suffix = code and msg or nil
			if message_suffix then
				error_handler.notify_error("Plot Error", error_code, nil, nil, message_suffix)
			else
				error_handler.notify_error("Plot Error", error_code)
			end
		end
		core.initiate_plot(final_opts)
	end)
end

function M.insert_snippet(bufnr, selection_end_line, plot_path)
	local width = (config.plotting or {}).snippet_width or "0.8\\linewidth"
	local first_result, second_result = io_util.find_math_block_end(bufnr, selection_end_line)
	local math_block_end
	if type(second_result) == "number" then
		math_block_end = second_result
	elseif type(first_result) == "number" then
		math_block_end = first_result
	end
	local snippet = string.format("\\includegraphics[width=%s]{%s}", width, plot_path)
	local lines_to_insert = { snippet }
	local insert_line = selection_end_line + 1
	if math_block_end ~= nil then
		insert_line = math_block_end + 1
		lines_to_insert = { "", snippet }
	else
		warn_missing_math_block_end()
	end
	vim.api.nvim_buf_set_lines(bufnr, insert_line, insert_line, false, lines_to_insert)
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
	local parsed = style_parser.parse(series.style_tokens or series.style)
	return {
		color = series.color or parsed.color or "auto",
		linewidth = series.linewidth or parsed.linewidth or "1.5",
		linestyle = series.linestyle or parsed.linestyle or "solid",
		marker = series.marker or parsed.marker or "none",
		markersize = series.markersize or parsed.markersize or "6",
		alpha = series.alpha or parsed.alpha or "1.0",
	}
end

local function series_supports_markers(series)
	return series and series.kind == "points"
end

local function build_default_lines(opts)
	opts = opts or {}
	local defaults = config.plotting or {}
	local classification = opts.classification or {}
	local form = classification.form or opts.form or "explicit"
	local dim = classification.dim or opts.dim or 2
	local show_colormap = not (form == "explicit" and dim == 2)
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
	local legend_placement = opts.legend_placement or opts.legend_position or "ne"
	local dependents = collect_dependents(series, dim, form)
	local lines = {}
	lines[#lines + 1] = "Form: " .. form
	lines[#lines + 1] = "Backend: " .. backend
	lines[#lines + 1] = "Output mode: " .. outputmode
	lines[#lines + 1] = "Aspect: " .. aspect
	lines[#lines + 1] = "Legend: " .. legend_state
	lines[#lines + 1] = "Legend placement: " .. legend_placement
	lines[#lines + 1] = string.format("Dependents: %s%s", dependents, DEPENDENTS_HINT)
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
	if show_colormap then
		lines[#lines + 1] = "Colormap: " .. tostring(opts.colormap or "viridis")
	end
	lines[#lines + 1] = "Colorbar: " .. (opts.colorbar == nil and "off" or to_on_off(opts.colorbar))
	lines[#lines + 1] = "Background: " .. tostring(opts.bg_color or "white")
	lines[#lines + 1] = ""
	for i, s in ipairs(series) do
		local defaults_for_series = get_series_defaults(s)
		local supports_markers = series_supports_markers(s)
		lines[#lines + 1] = string.format("--- Series %d: %s ---", i, s.ast or "")
		lines[#lines + 1] = "Label: " .. (s.label or "")
		lines[#lines + 1] = string.format("Dependents: %s%s", collect_dependents({ s }, dim, form), DEPENDENTS_HINT)
		lines[#lines + 1] = "Color: " .. tostring(defaults_for_series.color)
		lines[#lines + 1] = "Linewidth: " .. tostring(defaults_for_series.linewidth)
		lines[#lines + 1] = "Linestyle: " .. tostring(defaults_for_series.linestyle)
		if supports_markers then
			lines[#lines + 1] = "Marker: " .. tostring(defaults_for_series.marker)
			lines[#lines + 1] = "Markersize: " .. tostring(defaults_for_series.markersize)
		end
		lines[#lines + 1] = "Alpha: " .. tostring(defaults_for_series.alpha)
		if i < #series then
			lines[#lines + 1] = ""
		end
	end
	return lines
end

local function normalize_toggle(value, allow_auto)
	if type(value) ~= "string" then
		return nil
	end
	local normalized = value:lower()
	if normalized == "on" or normalized == "true" or normalized == "yes" then
		return true
	elseif normalized == "off" or normalized == "false" or normalized == "no" then
		return false
	elseif allow_auto and normalized == "auto" then
		return "auto"
	end
	return nil
end

local function parse_number(value, key)
	local trimmed = vim.trim(value or "")
	local num = tonumber(trimmed)
	if num == nil then
		error_handler.notify_error("Plot Config", string.format("Invalid numeric value for %s", key))
		return nil
	end
	return num
end

local function parse_alpha(value)
	local alpha = parse_number(value, "Alpha")
	if not alpha then
		return nil
	end
	if alpha < 0 or alpha > 1 then
		error_handler.notify_error("Plot Config", "Alpha must be between 0 and 1")
		return nil
	end
	return alpha
end

local function parse_range_value(value, key)
	local trimmed = vim.trim(value or "")
	if trimmed == "" or trimmed == "[]" then
		return true, nil
	end
	if trimmed:lower() == "auto" then
		return true, nil
	end
	local start_val, end_val = trimmed:match("^%[?%s*(.-)%s*,%s*(.-)%s*%]?$")
	if not start_val then
		error_handler.notify_error("Plot Config", string.format("Invalid range format for %s", key))
		return false
	end
	local function parse_endpoint(str)
		local endpoint = vim.trim(str)
		if endpoint == "" then
			return nil
		end
		local num = tonumber(endpoint)
		if num ~= nil then
			return true, num
		end

		local ok_parse, parsed, err_msg = pcall(parser.parse, endpoint)
		if not ok_parse or not parsed then
			local reason = err_msg or "Could not parse range endpoint"
			error_handler.notify_error("Plot Config", string.format("%s for %s", reason, key))
			return false
		end

		if parsed.series then
			if #parsed.series ~= 1 then
				error_handler.notify_error("Plot Config", string.format("%s range must be a single expression", key))
				return false
			end
			parsed = parsed.series[1]
		end

		return true, parsed
	end
	local start_ok, start_parsed = parse_endpoint(start_val)
	if start_ok == false then
		return false
	end
	local end_ok, end_parsed = parse_endpoint(end_val)
	if end_ok == false then
		return false
	end
	if start_parsed == nil and end_parsed == nil then
		return true, nil
	end
	return true, { start_parsed, end_parsed }
end

local function normalize_allowed_forms(allowed_forms)
	if vim.tbl_islist(allowed_forms) then
		local normalized = {}
		for _, value in ipairs(allowed_forms) do
			normalized[tostring(value):lower()] = true
		end
		return normalized
	end
	return allowed_forms or { explicit = true, implicit = true, polar = true }
end

local function build_expected_keys(dim, form, base_series, show_colormap)
	local expected_global_keys = {
		["Form"] = true,
		["Backend"] = true,
		["Output mode"] = true,
		["Aspect"] = true,
		["Legend"] = true,
		["Legend placement"] = true,
		["Dependents"] = true,
		["Grid"] = true,
		["Colorbar"] = true,
		["Background"] = true,
	}

	if show_colormap then
		expected_global_keys["Colormap"] = true
	end

	if dim >= 1 then
		expected_global_keys["X-range"] = true
		expected_global_keys["X-scale"] = true
	end
	if dim >= 2 then
		expected_global_keys["Y-range"] = true
		expected_global_keys["Y-scale"] = true
	end
	if dim >= 3 then
		expected_global_keys["Z-range"] = true
		expected_global_keys["Z-scale"] = true
	end
	if form == "parametric" and dim == 2 then
		expected_global_keys["T-range"] = true
	elseif form == "parametric" and dim == 3 then
		expected_global_keys["U-range"] = true
		expected_global_keys["V-range"] = true
	elseif form == "polar" then
		expected_global_keys["Theta-range"] = true
	end
	if dim >= 3 then
		expected_global_keys["View elevation"] = true
		expected_global_keys["View azimuth"] = true
	end

	local expected_series_keys = {}
	for i, s in ipairs(base_series) do
		local keys = {
			["Label"] = true,
			["Dependents"] = true,
			["Color"] = true,
			["Linewidth"] = true,
			["Linestyle"] = true,
			["Alpha"] = true,
		}
		if series_supports_markers(s) then
			keys["Marker"] = true
			keys["Markersize"] = true
		end
		expected_series_keys[i] = keys
	end

	return expected_global_keys, expected_series_keys
end

local function ensure_expected_key(expected, key)
	if expected[key] then
		return true
	end
	error_handler.notify_error("Plot Config", string.format("Unknown key '%s'", key))
	return false
end

local function apply_dependents_override(target, raw_value, expected_value, label)
	local dependents_value = strip_dependents_hint(vim.trim(raw_value or ""))
	if dependents_value == "" or dependents_value:lower() == "auto" then
		target.dependents_mode = "auto"
		return true
	end
	if expected_value and dependents_value ~= expected_value then
		error_handler.notify_error(
			"Plot Config",
			string.format("%s cannot be changed (expected %s)", label, expected_value)
		)
		return false
	end
	return true
end

local function apply_range_override(overrides, key, trimmed)
	local ok, range_val = parse_range_value(trimmed, key)
	if not ok then
		return false
	end
	if range_val ~= nil then
		local map = {
			["X-range"] = "xrange",
			["Y-range"] = "yrange",
			["Z-range"] = "zrange",
			["T-range"] = "t_range",
			["U-range"] = "u_range",
			["V-range"] = "v_range",
			["Theta-range"] = "theta_range",
		}
		overrides[map[key]] = range_val
	end
	return true
end

local function parse_global_line(key, value, ctx)
	if not ensure_expected_key(ctx.expected_global_keys, key) then
		return false
	end
	ctx.seen_global_keys[key] = true
	local trimmed = vim.trim(value or "")

	if key == "Form" then
		local normalized = trimmed:lower()
		if not ctx.allowed_forms[normalized] then
			error_handler.notify_error("Plot Config", string.format("Unsupported plot form '%s'", trimmed))
			return false
		end
		if ctx.classification.form and ctx.classification.form ~= normalized then
			error_handler.notify_error(
				"Plot Config",
				string.format("Cannot change plot form from %s to %s", ctx.classification.form, normalized)
			)
			return false
		end
	elseif key == "Backend" then
		local normalized = trimmed:lower()
		if not ctx.allowed_backends[normalized] then
			error_handler.notify_error("Plot Config", string.format("Unsupported backend '%s'", trimmed))
			return false
		end
		ctx.overrides.backend = normalized
	elseif key == "Output mode" then
		local normalized = trimmed:lower()
		if not ctx.allowed_output_modes[normalized] then
			error_handler.notify_error("Plot Config", string.format("Unsupported output mode '%s'", trimmed))
			return false
		end
		ctx.overrides.outputmode = normalized
	elseif key == "Aspect" then
		ctx.overrides.aspect = trimmed
	elseif key == "Legend" then
		local toggle = normalize_toggle(trimmed, true)
		if toggle == nil then
			error_handler.notify_error("Plot Config", "Legend must be 'auto', 'on', or 'off'")
			return false
		end
		ctx.overrides.legend_auto = toggle == true or toggle == "auto"
	elseif key == "Legend placement" then
		ctx.overrides.legend_pos = trimmed
	elseif key == "Dependents" then
		return apply_dependents_override(ctx.overrides, trimmed, ctx.expected_dependents, "Dependents")
	elseif
		key == "X-range"
		or key == "Y-range"
		or key == "Z-range"
		or key == "T-range"
		or key == "U-range"
		or key == "V-range"
		or key == "Theta-range"
	then
		return apply_range_override(ctx.overrides, key, trimmed)
	elseif key == "Grid" then
		local toggle = normalize_toggle(trimmed, false)
		if toggle == nil then
			error_handler.notify_error("Plot Config", "Grid must be 'on' or 'off'")
			return false
		end
		ctx.overrides.grids = toggle
	elseif key == "X-scale" then
		ctx.overrides.xscale = trimmed
	elseif key == "Y-scale" then
		ctx.overrides.yscale = trimmed
	elseif key == "Z-scale" then
		ctx.overrides.zscale = trimmed
	elseif key == "View elevation" then
		local elev = parse_number(trimmed, "View elevation")
		if not elev then
			return false
		end
		ctx.overrides.view_elev = elev
	elseif key == "View azimuth" then
		local azim = parse_number(trimmed, "View azimuth")
		if not azim then
			return false
		end
		ctx.overrides.view_azim = azim
	elseif key == "Colormap" then
		ctx.overrides.colormap = trimmed
	elseif key == "Colorbar" then
		local toggle = normalize_toggle(trimmed, false)
		if toggle == nil then
			error_handler.notify_error("Plot Config", "Colorbar must be 'on' or 'off'")
			return false
		end
		ctx.overrides.colorbar = toggle
	elseif key == "Background" then
		ctx.overrides.bg_color = trimmed
	end

	return true
end

local function parse_series_line(key, value, ctx)
	local expected_keys = ctx.expected_series_keys[ctx.series_idx] or {}
	if not ensure_expected_key(expected_keys, key) then
		return false
	end
	ctx.seen_series_keys[ctx.series_idx][key] = true
	local trimmed = vim.trim(value or "")

	if key == "Label" then
		ctx.series_overrides[ctx.series_idx].label = trimmed
	elseif key == "Dependents" then
		return apply_dependents_override(
			ctx.series_overrides[ctx.series_idx],
			trimmed,
			ctx.expected_series_dependents[ctx.series_idx],
			string.format("Series %d dependents", ctx.series_idx)
		)
	elseif key == "Color" then
		ctx.series_overrides[ctx.series_idx].color = trimmed
	elseif key == "Linewidth" then
		local lw = parse_number(trimmed, "Linewidth")
		if not lw then
			return false
		end
		ctx.series_overrides[ctx.series_idx].linewidth = lw
	elseif key == "Linestyle" then
		ctx.series_overrides[ctx.series_idx].linestyle = trimmed
	elseif key == "Marker" then
		ctx.series_overrides[ctx.series_idx].marker = trimmed
	elseif key == "Markersize" then
		local ms = parse_number(trimmed, "Markersize")
		if not ms then
			return false
		end
		ctx.series_overrides[ctx.series_idx].markersize = ms
	elseif key == "Alpha" then
		local alpha = parse_alpha(trimmed)
		if not alpha then
			return false
		end
		ctx.series_overrides[ctx.series_idx].alpha = alpha
	end

	return true
end

local function ensure_all_keys_present(
	expected_global_keys,
	seen_global_keys,
	expected_series_keys,
	seen_series_keys,
	base_series
)
	for expected_key in pairs(expected_global_keys) do
		if not seen_global_keys[expected_key] then
			error_handler.notify_error("Plot Config", string.format("Missing key '%s'", expected_key))
			return false
		end
	end

	for i = 1, #base_series do
		if not seen_series_keys[i] then
			error_handler.notify_error("Plot Config", string.format("Missing configuration for series %d", i))
			return false
		end
		local expected_keys = expected_series_keys[i] or {}
		for key in pairs(expected_keys) do
			if not seen_series_keys[i][key] then
				error_handler.notify_error("Plot Config", string.format("Missing key '%s' for series %d", key, i))
				return false
			end
		end
	end

	return true
end

local function parse_advanced_buffer(lines, opts)
	local classification = opts.classification or {}
	local form = classification.form or opts.form or "explicit"
	local dim = classification.dim or opts.dim or 2
	local base_series = {}
	if type(opts.series) == "table" and #opts.series > 0 then
		base_series = opts.series
	elseif type(classification.series) == "table" and #classification.series > 0 then
		base_series = classification.series
	end

	local allowed_forms = normalize_allowed_forms(opts.allowed_forms)
	local allowed_backends = { wolfram = true, python = true }
	local allowed_output_modes = { latex = true, viewer = true, both = true }

	local show_colormap = not (form == "explicit" and dim == 2)

	local expected_global_keys, expected_series_keys = build_expected_keys(dim, form, base_series, show_colormap)

	local seen_global_keys = {}
	local seen_series_keys = {}
	local overrides = {}
	local series_overrides = {}
	local current_series

	local expected_dependents = collect_dependents(base_series, dim, form)
	local expected_series_dependents = {}
	for i, s in ipairs(base_series) do
		expected_series_dependents[i] = collect_dependents({ s }, dim, form)
	end

	for idx, line in ipairs(lines or {}) do
		if not line:match("^%s*$") then
			local series_idx = line:match("^%s*%-%-%-%s*Series%s+(%d+)%s*:")
			if series_idx then
				local parsed_idx = tonumber(series_idx)
				if not parsed_idx then
					error_handler.notify_error("Plot Config", string.format("Invalid series header on line %d", idx))
					return nil
				end
				if parsed_idx < 1 or parsed_idx > #base_series then
					error_handler.notify_error("Plot Config", string.format("Unexpected series index %d", parsed_idx))
					return nil
				end
				current_series = parsed_idx
				series_overrides[current_series] = series_overrides[current_series] or {}
				seen_series_keys[current_series] = seen_series_keys[current_series] or {}
			else
				local key, value = line:match("^%s*(.-)%s*:%s*(.-)%s*$")
				if not key then
					error_handler.notify_error("Plot Config", string.format("Unable to parse line %d", idx))
					return nil
				end

				local ok
				if current_series then
					ok = parse_series_line(key, value, {
						series_idx = current_series,
						expected_series_keys = expected_series_keys,
						seen_series_keys = seen_series_keys,
						series_overrides = series_overrides,
						expected_series_dependents = expected_series_dependents,
					})
				else
					ok = parse_global_line(key, value, {
						classification = classification,
						allowed_forms = allowed_forms,
						allowed_backends = allowed_backends,
						allowed_output_modes = allowed_output_modes,
						overrides = overrides,
						expected_global_keys = expected_global_keys,
						seen_global_keys = seen_global_keys,
						expected_dependents = expected_dependents,
					})
				end

				if not ok then
					return nil
				end
			end
		end
	end

	local all_keys_present =
		ensure_all_keys_present(expected_global_keys, seen_global_keys, expected_series_keys, seen_series_keys, base_series)
	if not all_keys_present then
		return nil
	end

	return { overrides = overrides, series = series_overrides }
end

M._advanced_helpers = {
	build_expected_keys = build_expected_keys,
	apply_dependents_override = apply_dependents_override,
	parse_global_line = parse_global_line,
	parse_series_line = parse_series_line,
	ensure_all_keys_present = ensure_all_keys_present,
}

function M.open_advanced_config(opts)
	opts = opts or {}
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(bufnr, string.format("tungsten://plot-config/%d", bufnr))
	vim.api.nvim_buf_set_option(bufnr, "buftype", "acwrite")
	vim.api.nvim_buf_set_option(bufnr, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
	local lines = build_default_lines(opts)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	local winid =
		vim.api.nvim_open_win(bufnr, true, { relative = "editor", width = 60, height = #lines, row = 1, col = 1 })
	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = bufnr,
		callback = function()
			local buffer_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			local parsed = parse_advanced_buffer(buffer_lines, opts)
			if not parsed then
				return
			end
			local classification = vim.deepcopy(opts.classification or {})
			local builder_overrides = vim.deepcopy(parsed.overrides or {})
			local dependents_mode = builder_overrides.dependents_mode
			builder_overrides.dependents_mode = nil
			local built = options_builder.build(classification, builder_overrides)
			local final_opts = vim.deepcopy(opts)
			final_opts.series = {}
			if built.series then
				for i, series_entry in ipairs(built.series) do
					final_opts.series[i] = vim.deepcopy(series_entry)
				end
			end
			local series_dependents = {}
			for i, edit in ipairs(parsed.series) do
				final_opts.series[i] = final_opts.series[i] or {}
				if edit.dependents_mode == "auto" then
					series_dependents[i] = true
				end
				for key, value in pairs(edit) do
					if key ~= "dependents_mode" then
						final_opts.series[i][key] = value
					end
				end
			end
			for key, value in pairs(built) do
				if key ~= "series" then
					final_opts[key] = value
				end
			end
			if dependents_mode == "auto" then
				final_opts.dependent_vars = nil
			end
			for idx in pairs(series_dependents) do
				if final_opts.series[idx] then
					final_opts.series[idx].dependent_vars = nil
				end
			end
			if type(opts.on_submit) == "function" then
				opts.on_submit(final_opts)
			else
				core.initiate_plot(final_opts)
			end
			pcall(vim.api.nvim_buf_set_option, bufnr, "modified", false)
			pcall(vim.api.nvim_win_close, winid, true)
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
		local style = style_parser.parse(s.style_tokens or s.style)
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
