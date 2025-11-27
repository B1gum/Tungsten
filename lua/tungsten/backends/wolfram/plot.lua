local base = require("tungsten.backends.plot_base")
local logger = require("tungsten.util.logger")
local async = require("tungsten.util.async")
local config = require("tungsten.config")
local executor = require("tungsten.backends.wolfram.executor")
local error_handler = require("tungsten.util.error_handler")
local error_parser = require("tungsten.backends.wolfram.wolfram_error")
local parser = require("tungsten.core.parser")
local constants = require("tungsten.core.constants")

local M = setmetatable({}, { __index = base })

local function render_ast_to_wolfram(ast)
	if not ast then
		return nil
	end
	local ok, code = pcall(executor.ast_to_code, ast)
	if ok then
		return code
	end
	return nil
end

local function axis_is_dependent(opts, axis_var)
	for _, series in ipairs(opts.series or {}) do
		for _, dep in ipairs(series.dependent_vars or {}) do
			if dep == axis_var then
				return true
			end
		end
	end
	return false
end

local axis_keys = { "x", "y", "z" }

local function axes_for_plot_range(opts)
	if not opts or not opts.dim or opts.dim <= 1 then
		return { "x" }
	elseif opts.dim >= 3 then
		return { "x", "y", "z" }
	end
	return { "x", "y" }
end

local function is_equality_node(ast)
	if type(ast) ~= "table" then
		return false
	end
	local t = ast.type
	return t == "equality" or t == "Equality"
end

local function unwrap_equality_rhs(ast)
	if is_equality_node(ast) and ast.rhs then
		return ast.rhs
	end
	return ast
end

local function to_wolfram_value(value)
	if value == nil or type(value) == "number" then
		return value
	end
	if type(value) ~= "string" then
		return value
	end

	local ok, parsed_ast = pcall(parser.parse, value, { simple_mode = true })
	if ok and parsed_ast then
		local rendered = render_ast_to_wolfram(parsed_ast)
		if rendered and not tostring(rendered):match("^Error") then
			return rendered
		end
	end

	local const_name = value:match("^%-?\\([A-Za-z]+)$")
	if const_name then
		local const_info = constants.get(const_name)
		if const_info and const_info.wolfram then
			local prefix = value:sub(1, 1) == "-" and "-" or ""
			return prefix .. const_info.wolfram
		end
	end

	return value
end

local function normalize_ranges(opts)
	local keys = { "xrange", "yrange", "zrange", "t_range", "u_range", "v_range", "theta_range" }
	for _, key in ipairs(keys) do
		local range = opts[key]
		if type(range) == "table" then
			opts[key] = { to_wolfram_value(range[1]), to_wolfram_value(range[2]) }
		end
	end
end

local function axis_marked_for_clip(opts, axis_name, axis_var)
	local clip_axes = opts.clip_axes
	if type(clip_axes) == "table" then
		local flag = clip_axes[axis_name]
		if flag == nil and axis_var then
			flag = clip_axes[axis_var]
		end
		if flag ~= nil then
			return flag and true or false
		end
	end

	local dep_check = axis_var or axis_name
	if axis_name ~= "x" and opts.clip_dependent_axes and axis_is_dependent(opts, dep_check) then
		return true
	end

	return false
end

local function determine_axis_variables(opts)
	local axis_vars = { x = "x", y = "y", z = "z" }
	if not opts or opts.form ~= "explicit" then
		return axis_vars
	end

	local series = opts.series or {}
	local first = series[1] or {}
	local indep = first.independent_vars or {}
	local dep = first.dependent_vars or {}

	axis_vars.x = indep[1] or axis_vars.x
	if opts.dim == 3 then
		axis_vars.y = indep[2] or axis_vars.y
		axis_vars.z = dep[1] or axis_vars.z
	else
		axis_vars.y = dep[1] or axis_vars.y
	end

	return axis_vars
end

local function invert_axis_variables(axis_vars)
	local lookup = {}
	for axis_name, var_name in pairs(axis_vars or {}) do
		if type(var_name) == "string" then
			lookup[var_name] = axis_name
		end
	end
	return lookup
end

local function resolve_range_for_var(opts, axis_ranges, var_name, axis_name)
	if var_name and axis_ranges[var_name] then
		return axis_ranges[var_name]
	end
	if var_name then
		local clip_axes = opts.clip_axes
		if type(clip_axes) == "table" then
			local alias = clip_axes[var_name]
			if type(alias) == "string" and axis_ranges[alias] then
				return axis_ranges[alias]
			end
		end
	end
	if axis_name and axis_ranges[axis_name] then
		return axis_ranges[axis_name]
	end
	return nil
end

local function translate_opts_to_wolfram(opts)
	local res = {}

	local axis_vars = determine_axis_variables(opts)
	local var_to_axis = invert_axis_variables(axis_vars)

	local plot_ranges = {}
	local function maybe_add_plot_range(range_key, var_name, default_axis)
		local range = opts[range_key]
		if not range then
			return
		end
		local axis_name = (var_to_axis[var_name] or default_axis or var_name)
		if not axis_name then
			return
		end
		local axis_var = axis_vars[axis_name] or axis_name
		if not axis_marked_for_clip(opts, axis_name, axis_var) then
			return
		end
		plot_ranges[axis_name] = string.format("{%s, %s}", range[1], range[2])
	end

	maybe_add_plot_range("xrange", "x", "x")
	maybe_add_plot_range("yrange", "y", "y")
	maybe_add_plot_range("zrange", "z", "z")

	local ordered = {}
	local axes_to_emit = axes_for_plot_range(opts)
	local has_range = false
	for _, axis_name in ipairs(axes_to_emit) do
		local range = plot_ranges[axis_name]
		if range then
			has_range = true
			ordered[#ordered + 1] = range
		else
			ordered[#ordered + 1] = "Automatic"
		end
	end
	if has_range then
		table.insert(res, "PlotRange -> {" .. table.concat(ordered, ", ") .. "}")
	end

	local aspect = opts.aspect
	if aspect == "auto" then
		aspect = nil
	end
	if aspect then
		if opts.dim == 3 then
			if aspect == "equal" then
				table.insert(res, "BoxRatios -> {1,1,1}")
			else
				table.insert(res, "BoxRatios -> Automatic")
			end
		else
			if aspect == "equal" then
				table.insert(res, "AspectRatio -> 1")
			else
				table.insert(res, "AspectRatio -> Automatic")
			end
		end
	end

	if opts.dim == 2 then
		if opts.grids then
			table.insert(res, "GridLines -> Automatic")
		else
			table.insert(res, "GridLines -> None")
		end
	end

	if opts.crop then
		table.insert(res, "ImageMargins -> 0")
		table.insert(res, "ImagePadding -> All")
		table.insert(res, "PlotRangePadding -> Scaled[0.02]")
	end

	return res
end

local function ensure_option(extra_opts, needle, option_str)
	for _, opt in ipairs(extra_opts or {}) do
		if opt:find(needle, 1, true) then
			return
		end
	end
	extra_opts[#extra_opts + 1] = option_str
end

local function build_style_directive(series)
	local parts = {}
	if series.color then
		parts[#parts + 1] = series.color
	end
	if series.linewidth then
		parts[#parts + 1] = string.format("AbsoluteThickness[%s]", series.linewidth)
	end
	if series.linestyle then
		parts[#parts + 1] = series.linestyle
	end
	if series.alpha then
		parts[#parts + 1] = string.format("Opacity[%s]", series.alpha)
	end
	if series.markersize then
		parts[#parts + 1] = string.format("PointSize[%s]", series.markersize)
	end
	if #parts > 0 then
		return "Directive[" .. table.concat(parts, ", ") .. "]"
	end
	return nil
end

local function series_supports_markers(series)
	return series and series.kind == "points"
end

local function build_marker_spec(series)
	if not series_supports_markers(series) then
		return nil
	end
	local marker = series.marker
	if type(marker) == "string" then
		local lowered = marker:lower()
		if lowered == "none" or lowered == "off" then
			return nil
		end
	end

	if marker or series.markersize then
		local marker_spec = marker and string.format('"%s"', marker) or "Automatic"
		local size = series.markersize and tostring(series.markersize) or "Automatic"
		return string.format("{%s, %s}", marker_spec, size)
	end
	return nil
end

local function apply_series_styles(extra_opts, series)
	local styles = {}
	local markers = {}
	for _, s in ipairs(series or {}) do
		local st = build_style_directive(s)
		if st then
			styles[#styles + 1] = st
		end
		local mk = build_marker_spec(s)
		if mk then
			markers[#markers + 1] = mk
		end
	end
	if #styles > 0 then
		if #styles == 1 then
			extra_opts[#extra_opts + 1] = "PlotStyle -> " .. styles[1]
		else
			extra_opts[#extra_opts + 1] = "PlotStyle -> {" .. table.concat(styles, ", ") .. "}"
		end
	end
	if #markers > 0 then
		if #markers == 1 then
			extra_opts[#extra_opts + 1] = "PlotMarkers -> " .. markers[1]
		else
			extra_opts[#extra_opts + 1] = "PlotMarkers -> {" .. table.concat(markers, ", ") .. "}"
		end
	end
end

local function translate_legend_pos(pos)
	if type(pos) == "string" then
		local lowered = pos:lower()
		local compass = {
			n = "upper center",
			ne = "upper right",
			e = "center right",
			se = "lower right",
			s = "lower center",
			sw = "lower left",
			w = "center left",
			nw = "upper left",
			c = "center",
		}
		pos = compass[lowered] or pos
	end
	local map = {
		["upper right"] = "Scaled[{1, 1}]",
		["upper left"] = "Scaled[{0, 1}]",
		["lower left"] = "Scaled[{0, 0}]",
		["lower right"] = "Scaled[{1, 0}]",
		["center"] = "Scaled[{0.5, 0.5}]",
	}
	return map[pos] or pos
end

local function apply_legend(extra_opts, opts)
	local labels = {}
	for _, s in ipairs(opts.series or {}) do
		if s.label and s.label ~= "" then
			labels[#labels + 1] = string.format('"%s"', s.label)
		end
	end
	if #labels > 0 then
		local legend = "{" .. table.concat(labels, ", ") .. "}"
		if opts.legend_auto == false and opts.legend_pos then
			legend = string.format("Placed[%s, %s]", legend, translate_legend_pos(opts.legend_pos))
		end
		extra_opts[#extra_opts + 1] = "PlotLegends -> " .. legend
	end
end

local function build_explicit_code(opts)
	local series = opts.series or {}
	local functions = {}
	local point_sets = {}
	for _, s in ipairs(series) do
		if s.kind == "function" then
			local ast = unwrap_equality_rhs(s.ast)
			local code = render_ast_to_wolfram(ast)
			if code then
				table.insert(functions, code)
			end
		elseif s.kind == "points" then
			local coords = {}
			for _, p in ipairs(s.points or {}) do
				local x = render_ast_to_wolfram(p.x)
				local y = render_ast_to_wolfram(p.y)
				local z = p.z and render_ast_to_wolfram(p.z)
				if x and y and (opts.dim ~= 3 or z) then
					if opts.dim == 3 then
						coords[#coords + 1] = string.format("{%s, %s, %s}", x, y, z)
					else
						coords[#coords + 1] = string.format("{%s, %s}", x, y)
					end
				end
			end
			if #coords > 0 then
				point_sets[#point_sets + 1] = coords
			end
		end
	end
	if #functions == 0 and #point_sets == 0 then
		return nil, "No functions to plot"
	end

	local indep = series[1] and series[1].independent_vars or {}
	local axis_vars = determine_axis_variables(opts)
	local var_to_axis = invert_axis_variables(axis_vars)
	local axis_ranges = { x = opts.xrange, y = opts.yrange, z = opts.zrange }
	local ranges = {}
	for i, var_name in ipairs(indep) do
		local fallback_axis = axis_keys[i]
		local axis_name = var_to_axis[var_name] or fallback_axis
		local range = resolve_range_for_var(opts, axis_ranges, var_name, axis_name)
		if range then
			table.insert(ranges, string.format("{%s, %s, %s}", var_name, range[1], range[2]))
		end
	end

	local plots = {}
	if #functions > 0 then
		local func_expr
		if #functions == 1 then
			func_expr = functions[1]
		else
			func_expr = "{" .. table.concat(functions, ", ") .. "}"
		end

		local plot_fun = opts.dim == 3 and "Plot3D" or "Plot"
		local code = plot_fun .. "[" .. func_expr .. ", " .. table.concat(ranges, ", ")

		local extra_opts = translate_opts_to_wolfram(opts)
		apply_series_styles(extra_opts, series)
		if #extra_opts > 0 then
			code = code .. ", " .. table.concat(extra_opts, ", ")
		end
		code = code .. "]"
		plots[#plots + 1] = code
	end

	if #point_sets > 0 then
		local list_expr
		if #point_sets == 1 then
			list_expr = "{" .. table.concat(point_sets[1], ", ") .. "}"
		else
			local wrapped = {}
			for _, set in ipairs(point_sets) do
				wrapped[#wrapped + 1] = "{" .. table.concat(set, ", ") .. "}"
			end
			list_expr = "{" .. table.concat(wrapped, ", ") .. "}"
		end

		local plot_fun = opts.dim == 3 and "ListPointPlot3D" or "ListPlot"
		local plot_range
		if opts.dim == 3 then
			if opts.xrange or opts.yrange or opts.zrange then
				local xr = opts.xrange or { "Automatic", "Automatic" }
				local yr = opts.yrange or { "Automatic", "Automatic" }
				local zr = opts.zrange or { "Automatic", "Automatic" }
				plot_range =
					string.format("PlotRange -> {{%s, %s}, {%s, %s}, {%s, %s}}", xr[1], xr[2], yr[1], yr[2], zr[1], zr[2])
			end
		elseif opts.xrange or opts.yrange then
			local xr = opts.xrange or { "Automatic", "Automatic" }
			local yr = opts.yrange or { "Automatic", "Automatic" }
			plot_range = string.format("PlotRange -> {{%s, %s}, {%s, %s}}", xr[1], xr[2], yr[1], yr[2])
		end

		local extras = {}
		if plot_range then
			extras[#extras + 1] = plot_range
		end
		if opts.legend_auto == false and opts.legend_pos then
			extras[#extras + 1] = string.format("PlotLegends -> Placed[{}, %s]", translate_legend_pos(opts.legend_pos))
		end

		local point_plot = plot_fun .. "[" .. list_expr
		if #extras > 0 then
			point_plot = point_plot .. ", " .. table.concat(extras, ", ")
		end
		point_plot = point_plot .. "]"
		plots[#plots + 1] = point_plot
	end

	if #plots == 1 then
		return plots[1]
	end

	return string.format("Show[{%s}]", table.concat(plots, ", "))
end

local function build_implicit_code(opts)
	local series = opts.series or {}
	local exprs = {}
	local has_inequality = false
	for _, s in ipairs(series) do
		if s.kind == "function" or s.kind == "inequality" then
			if s.kind == "inequality" then
				has_inequality = true
				s.alpha = s.alpha or 0.4
			end
			local code = render_ast_to_wolfram(s.ast)
			if code then
				table.insert(exprs, code)
			end
		end
	end
	if #exprs == 0 then
		return nil, "No expressions to plot"
	end

	local indep = series[1] and series[1].independent_vars or {}
	local ranges = {}
	if indep[1] and opts.xrange then
		table.insert(ranges, string.format("{%s, %s, %s}", indep[1], opts.xrange[1], opts.xrange[2]))
	end
	if indep[2] and opts.yrange then
		table.insert(ranges, string.format("{%s, %s, %s}", indep[2], opts.yrange[1], opts.yrange[2]))
	end
	if indep[3] and opts.zrange then
		table.insert(ranges, string.format("{%s, %s, %s}", indep[3], opts.zrange[1], opts.zrange[2]))
	end

	local expr
	if #exprs == 1 then
		expr = exprs[1]
	else
		expr = "{" .. table.concat(exprs, ", ") .. "}"
	end

	local fn
	if has_inequality then
		fn = opts.dim == 3 and "RegionPlot3D" or "RegionPlot"
	else
		fn = opts.dim == 3 and "ContourPlot3D" or "ContourPlot"
	end

	local code = fn .. "[" .. expr .. ", " .. table.concat(ranges, ", ")
	local extra_opts = translate_opts_to_wolfram(opts)
	if opts.plot_points then
		extra_opts[#extra_opts + 1] = string.format("PlotPoints -> %d", opts.plot_points)
	end
	if opts.max_recursion then
		extra_opts[#extra_opts + 1] = string.format("MaxRecursion -> %d", opts.max_recursion)
	end
	if opts.dim == 3 then
		if fn == "RegionPlot3D" then
			ensure_option(extra_opts, "BoundaryStyle", "BoundaryStyle -> None")
		elseif fn == "ContourPlot3D" then
			ensure_option(extra_opts, "Mesh", "Mesh -> None")
		end
	end
	apply_series_styles(extra_opts, series)
	apply_legend(extra_opts, opts)
	if #extra_opts > 0 then
		code = code .. ", " .. table.concat(extra_opts, ", ")
	end
	code = code .. "]"

	return code
end

local function build_parametric_code(opts)
	local series = opts.series or {}
	local exprs = {}
	for _, s in ipairs(series) do
		if s.kind == "function" then
			if opts.dim == 3 then
				local x = render_ast_to_wolfram(s.ast.x)
				local y = render_ast_to_wolfram(s.ast.y)
				local z = render_ast_to_wolfram(s.ast.z)
				if x and y and z then
					table.insert(exprs, string.format("{%s, %s, %s}", x, y, z))
				end
			else
				local x = render_ast_to_wolfram(s.ast.x)
				local y = render_ast_to_wolfram(s.ast.y)
				if x and y then
					table.insert(exprs, string.format("{%s, %s}", x, y))
				end
			end
		end
	end
	if #exprs == 0 then
		return nil, "No parametric expressions"
	end

	local indep = series[1] and series[1].independent_vars or {}
	local ranges = {}
	if opts.dim == 3 then
		local u = indep[1] or "u"
		local v = indep[2] or "v"
		local ur = opts.u_range or { 0, 1 }
		local vr = opts.v_range or { 0, 1 }
		table.insert(ranges, string.format("{%s, %s, %s}", u, ur[1], ur[2]))
		table.insert(ranges, string.format("{%s, %s, %s}", v, vr[1], vr[2]))
	else
		local t = indep[1] or "t"
		local tr = opts.t_range or { 0, 1 }
		table.insert(ranges, string.format("{%s, %s, %s}", t, tr[1], tr[2]))
	end

	local inner
	if #exprs == 1 then
		inner = exprs[1]
	else
		inner = "{" .. table.concat(exprs, ", ") .. "}"
	end

	local fn = opts.dim == 3 and "ParametricPlot3D" or "ParametricPlot"
	local code = fn .. "[" .. inner .. ", " .. table.concat(ranges, ", ")
	local extra_opts = translate_opts_to_wolfram(opts)
	apply_series_styles(extra_opts, series)
	apply_legend(extra_opts, opts)
	if #extra_opts > 0 then
		code = code .. ", " .. table.concat(extra_opts, ", ")
	end
	code = code .. "]"

	return code
end

local function extract_polar_expression(ast)
	if not ast then
		return nil
	end
	if ast.r then
		return ast.r
	end
	return unwrap_equality_rhs(ast)
end

local function build_polar_code(opts)
	local series = opts.series or {}
	local exprs = {}
	for _, s in ipairs(series) do
		if s.kind == "function" then
			local expr_ast = extract_polar_expression(s.ast)
			local code = render_ast_to_wolfram(expr_ast)
			if code then
				table.insert(exprs, code)
			end
		end
	end
	if #exprs == 0 then
		return nil, "No polar functions to plot"
	end

	local indep = series[1] and series[1].independent_vars or {}
	local theta_var = indep[1] or "theta"
	local theta_range = opts.theta_range or { 0, "2*Pi" }
	local theta_min = theta_range[1] or 0
	local theta_max = theta_range[2] or "2*Pi"
	local domain = string.format("{%s, %s, %s}", theta_var, theta_min, theta_max)

	local inner
	if #exprs == 1 then
		inner = exprs[1]
	else
		inner = "{" .. table.concat(exprs, ", ") .. "}"
	end

	local code = "PolarPlot[" .. inner .. ", " .. domain
	local extra_opts = translate_opts_to_wolfram(opts)
	if opts.samples then
		extra_opts[#extra_opts + 1] = string.format("PlotPoints -> %d", opts.samples)
	end
	apply_series_styles(extra_opts, series)
	apply_legend(extra_opts, opts)
	if #extra_opts > 0 then
		code = code .. ", " .. table.concat(extra_opts, ", ")
	end
	code = code .. "]"

	return code
end

function M.build_plot_code(opts)
	normalize_ranges(opts)
	if opts.form == "explicit" then
		return build_explicit_code(opts)
	elseif opts.form == "implicit" then
		return build_implicit_code(opts)
	elseif opts.form == "parametric" then
		return build_parametric_code(opts)
	elseif opts.form == "polar" then
		return build_polar_code(opts)
	else
		return nil, "Unsupported plot form"
	end
end

local function build_export_code(opts, plot_code)
	local fmt = (opts.format or "png"):upper()
	local export_opts = {}
	if opts.dpi then
		table.insert(export_opts, string.format("ImageResolution -> %d", opts.dpi))
	end
	local export_str = string.format('Export["%s", %s, "%s"', opts.out_path, plot_code, fmt)
	if #export_opts > 0 then
		export_str = export_str .. ", " .. table.concat(export_opts, ", ")
	end
	export_str = export_str .. "]"
	return export_str
end

function M.translate_plot_error(exit_code, stdout, stderr)
	stdout = stdout or ""
	stderr = stderr or ""
	local msg = stderr ~= "" and stderr or stdout
	if msg == "" then
		msg = string.format("wolframscript exited with code %d", exit_code)
	end
	local normalized = error_parser.parse_wolfram_error(msg) or msg
	local lowered = normalized and normalized:lower() or ""
	local code
	if lowered:find("contourplot::cpcon", 1, true) then
		code = error_handler.E_NO_CONTOUR
	elseif lowered:find("contourplot3d::ncvb", 1, true) then
		code = error_handler.E_NO_ISOSURFACE
	end
	return {
		code = code,
		message = normalized,
	}
end

function M.plot_async(opts, callback)
	opts = opts or {}
	assert(type(callback) == "function", "plot async expects a callback")

	logger.debug("Wolfram plot", "plot_async called")

	if not opts.out_path then
		callback("Missing out_path", nil)
		return
	end

	normalize_ranges(opts)

	local plot_code, err = M.build_plot_code(opts)
	if not plot_code then
		callback(err or "Failed to build plot code", nil)
		return
	end

	local code = build_export_code(opts, plot_code)

	local wolfram_opts = config.backend_opts and config.backend_opts.wolfram or {}
	local wolfram_path = wolfram_opts.wolfram_path or "wolframscript"

	async.run_job({ wolfram_path, "-code", code }, {
		timeout = opts.timeout_ms,
		on_exit = function(exit_code, stdout, stderr)
			if exit_code == 0 then
				if callback then
					callback(nil, stdout)
				end
			else
				local translated = M.translate_plot_error(exit_code, stdout, stderr)
				local errcb = {
					code = exit_code,
					exit_code = exit_code,
					message = translated.message,
					backend_error_code = translated.code,
				}
				if callback then
					callback(errcb, nil)
				end
			end
		end,
	})
end

return M
