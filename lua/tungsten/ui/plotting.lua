local core = require("tungsten.core.plotting")
local error_handler = require("tungsten.util.error_handler")
local state = require("tungsten.state")
local config = require("tungsten.config")
local async = require("tungsten.util.async")
local io_util = require("tungsten.util.io")
local options_builder = require("tungsten.domains.plotting.options_builder")

local M = {}

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
	local first_result, second_result = io_util.find_math_block_end(bufnr, selection_end_line)
	local math_block_end
	if type(second_result) == "number" then
		math_block_end = second_result
	elseif type(first_result) == "number" then
		math_block_end = first_result
	end
	local snippet = string.format("\\includegraphics[width=%s]{%s}", width, plot_path)
	local lines_to_insert = { snippet }
	local insert_line = selection_end_line
	if math_block_end ~= nil then
		insert_line = math_block_end + 1
		lines_to_insert = { "", snippet }
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
		on_exit = function(code, err)
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
	lines[#lines + 1] = "Colormap: " .. tostring(opts.colormap or "viridis")
	lines[#lines + 1] = "Colorbar: " .. (opts.colorbar == nil and "off" or to_on_off(opts.colorbar))
	lines[#lines + 1] = "Background: " .. tostring(opts.bg_color or "white")
	lines[#lines + 1] = ""
	for i, s in ipairs(series) do
		local defaults_for_series = get_series_defaults(s)
		lines[#lines + 1] = string.format("--- Series %d: %s ---", i, s.ast or "")
		lines[#lines + 1] = "Label: " .. (s.label or "")
		lines[#lines + 1] = string.format("Dependents: %s%s", collect_dependents({ s }, dim, form), DEPENDENTS_HINT)
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
		return num or endpoint
	end
	local start_parsed = parse_endpoint(start_val)
	local end_parsed = parse_endpoint(end_val)
	if start_parsed == nil and end_parsed == nil then
		return true, nil
	end
	return true, { start_parsed, end_parsed }
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

	local allowed_forms = { explicit = true, implicit = true, parametric = true, polar = true }
	local allowed_backends = { wolfram = true, python = true }
	local allowed_output_modes = { latex = true, viewer = true, both = true }

	local expected_global_keys = {
		["Form"] = true,
		["Backend"] = true,
		["Output mode"] = true,
		["Aspect"] = true,
		["Legend"] = true,
		["Legend placement"] = true,
		["Dependents"] = true,
		["Grid"] = true,
		["Colormap"] = true,
		["Colorbar"] = true,
		["Background"] = true,
	}

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
		expected_global_keys["View elevation"] = true
		expected_global_keys["View azimuth"] = true
	end
	if form == "parametric" and dim == 2 then
		expected_global_keys["T-range"] = true
	elseif form == "parametric" and dim == 3 then
		expected_global_keys["U-range"] = true
		expected_global_keys["V-range"] = true
	elseif form == "polar" then
		expected_global_keys["Theta-range"] = true
	end

	local expected_series_keys = {
		["Label"] = true,
		["Dependents"] = true,
		["Color"] = true,
		["Linewidth"] = true,
		["Linestyle"] = true,
		["Marker"] = true,
		["Markersize"] = true,
		["Alpha"] = true,
	}

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
		if line:match("^%s*$") then
			goto continue
		end
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
			goto continue
		end

		local key, value = line:match("^%s*(.-)%s*:%s*(.-)%s*$")
		if not key then
			error_handler.notify_error("Plot Config", string.format("Unable to parse line %d", idx))
			return nil
		end

		if current_series then
			if not expected_series_keys[key] then
				error_handler.notify_error("Plot Config", string.format("Unknown series key '%s'", key))
				return nil
			end
			seen_series_keys[current_series][key] = true
			local trimmed = vim.trim(value or "")
			if key == "Label" then
				series_overrides[current_series].label = trimmed
			elseif key == "Dependents" then
				local expected_value = expected_series_dependents[current_series]
				local dependents_value = strip_dependents_hint(trimmed)
				if dependents_value == "" or dependents_value:lower() == "auto" then
					series_overrides[current_series].dependents_mode = "auto"
				elseif expected_value and dependents_value ~= expected_value then
					error_handler.notify_error(
						"Plot Config",
						string.format("Series %d dependents cannot be changed (expected %s)", current_series, expected_value)
					)
					return nil
				end
			elseif key == "Color" then
				series_overrides[current_series].color = trimmed
			elseif key == "Linewidth" then
				local lw = parse_number(trimmed, "Linewidth")
				if not lw then
					return nil
				end
				series_overrides[current_series].linewidth = lw
			elseif key == "Linestyle" then
				series_overrides[current_series].linestyle = trimmed
			elseif key == "Marker" then
				series_overrides[current_series].marker = trimmed
			elseif key == "Markersize" then
				local ms = parse_number(trimmed, "Markersize")
				if not ms then
					return nil
				end
				series_overrides[current_series].markersize = ms
			elseif key == "Alpha" then
				local alpha = parse_alpha(trimmed)
				if not alpha then
					return nil
				end
				series_overrides[current_series].alpha = alpha
			end
		else
			if not expected_global_keys[key] then
				error_handler.notify_error("Plot Config", string.format("Unknown key '%s'", key))
				return nil
			end
			seen_global_keys[key] = true
			local trimmed = vim.trim(value or "")
			if key == "Form" then
				local normalized = trimmed:lower()
				if not allowed_forms[normalized] then
					error_handler.notify_error("Plot Config", string.format("Unsupported plot form '%s'", trimmed))
					return nil
				end
				if classification.form and classification.form ~= normalized then
					error_handler.notify_error(
						"Plot Config",
						string.format("Cannot change plot form from %s to %s", classification.form, normalized)
					)
					return nil
				end
			elseif key == "Backend" then
				local normalized = trimmed:lower()
				if not allowed_backends[normalized] then
					error_handler.notify_error("Plot Config", string.format("Unsupported backend '%s'", trimmed))
					return nil
				end
				overrides.backend = normalized
			elseif key == "Output mode" then
				local normalized = trimmed:lower()
				if not allowed_output_modes[normalized] then
					error_handler.notify_error("Plot Config", string.format("Unsupported output mode '%s'", trimmed))
					return nil
				end
				overrides.outputmode = normalized
			elseif key == "Aspect" then
				overrides.aspect = trimmed
			elseif key == "Legend" then
				local toggle = normalize_toggle(trimmed, true)
				if toggle == nil then
					error_handler.notify_error("Plot Config", "Legend must be 'auto', 'on', or 'off'")
					return nil
				end
				if toggle == true or toggle == "auto" then
					overrides.legend_auto = true
				else
					overrides.legend_auto = false
				end
			elseif key == "Legend placement" then
				overrides.legend_pos = trimmed
			elseif key == "Dependents" then
				local dependents_value = strip_dependents_hint(trimmed)
				if dependents_value == "" or dependents_value:lower() == "auto" then
					overrides.dependents_mode = "auto"
				elseif dependents_value ~= expected_dependents then
					error_handler.notify_error(
						"Plot Config",
						string.format("Dependents cannot be changed (expected %s)", expected_dependents)
					)
					return nil
				end
			elseif
				key == "X-range"
				or key == "Y-range"
				or key == "Z-range"
				or key == "T-range"
				or key == "U-range"
				or key == "V-range"
				or key == "Theta-range"
			then
				local ok, range_val = parse_range_value(trimmed, key)
				if not ok then
					return nil
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
			elseif key == "Grid" then
				local toggle = normalize_toggle(trimmed, false)
				if toggle == nil then
					error_handler.notify_error("Plot Config", "Grid must be 'on' or 'off'")
					return nil
				end
				overrides.grids = toggle
			elseif key == "X-scale" then
				overrides.xscale = trimmed
			elseif key == "Y-scale" then
				overrides.yscale = trimmed
			elseif key == "Z-scale" then
				overrides.zscale = trimmed
			elseif key == "View elevation" then
				local elev = parse_number(trimmed, "View elevation")
				if not elev then
					return nil
				end
				overrides.view_elev = elev
			elseif key == "View azimuth" then
				local azim = parse_number(trimmed, "View azimuth")
				if not azim then
					return nil
				end
				overrides.view_azim = azim
			elseif key == "Colormap" then
				overrides.colormap = trimmed
			elseif key == "Colorbar" then
				local toggle = normalize_toggle(trimmed, false)
				if toggle == nil then
					error_handler.notify_error("Plot Config", "Colorbar must be 'on' or 'off'")
					return nil
				end
				overrides.colorbar = toggle
			elseif key == "Background" then
				overrides.bg_color = trimmed
			end
		end
		::continue::
	end

	for expected_key in pairs(expected_global_keys) do
		if not seen_global_keys[expected_key] then
			error_handler.notify_error("Plot Config", string.format("Missing key '%s'", expected_key))
			return nil
		end
	end

	for i = 1, #base_series do
		if not seen_series_keys[i] then
			error_handler.notify_error("Plot Config", string.format("Missing configuration for series %d", i))
			return nil
		end
		for key in pairs(expected_series_keys) do
			if not seen_series_keys[i][key] then
				error_handler.notify_error("Plot Config", string.format("Missing key '%s' for series %d", key, i))
				return nil
			end
		end
	end

	return { overrides = overrides, series = series_overrides }
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
			local buffer_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
			local parsed = parse_advanced_buffer(buffer_lines, opts)
			if not parsed then
				return
			end
			vim.ui.input({ prompt = "Generate plot with current configuration? (y/N): " }, function(answer)
				if answer and answer:match("^%s*[Yy]") then
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
					core.initiate_plot(final_opts)
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
