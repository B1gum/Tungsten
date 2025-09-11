local base = require("tungsten.backends.plot_base")
local logger = require("tungsten.util.logger")
local async = require("tungsten.util.async")
local config = require("tungsten.config")
local executor = require("tungsten.backends.wolfram.executor")

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

local function translate_opts_to_wolfram(opts)
	local res = {}

	if opts.xrange or opts.yrange or opts.zrange then
		local ranges = {}
		if opts.xrange then
			table.insert(ranges, string.format("{%s, %s}", opts.xrange[1], opts.xrange[2]))
		end
		if opts.yrange then
			table.insert(ranges, string.format("{%s, %s}", opts.yrange[1], opts.yrange[2]))
		end
		if opts.zrange then
			table.insert(ranges, string.format("{%s, %s}", opts.zrange[1], opts.zrange[2]))
		end
		table.insert(res, "PlotRange -> {" .. table.concat(ranges, ", ") .. "}")
	end

	if opts.aspect then
		if opts.dim == 3 then
			if opts.aspect == "equal" then
				table.insert(res, "BoxRatios -> {1,1,1}")
			else
				table.insert(res, "BoxRatios -> Automatic")
			end
		else
			if opts.aspect == "equal" then
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

	if opts.figsize_in then
		local w = math.floor((opts.figsize_in[1] or 0) * 72 + 0.5)
		local h = math.floor((opts.figsize_in[2] or 0) * 72 + 0.5)
		table.insert(res, string.format("ImageSize -> {%d, %d}", w, h))
	end

	return res
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

local function build_marker_spec(series)
	if series.marker or series.markersize then
		local marker = series.marker and string.format('"%s"', series.marker) or "Automatic"
		local size = series.markersize and tostring(series.markersize) or "Automatic"
		return string.format("{%s, %s}", marker, size)
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

local function build_explicit_code(opts)
	local series = opts.series or {}
	local functions = {}
	for _, s in ipairs(series) do
		if s.kind == "function" then
			local ast = s.ast
			if ast and ast.type == "equality" and ast.rhs then
				ast = ast.rhs
			end
			local code = render_ast_to_wolfram(ast)
			if code then
				table.insert(functions, code)
			end
		end
	end
	if #functions == 0 then
		return nil, "No functions to plot"
	end

	local indep = series[1] and series[1].independent_vars or {}
	local ranges = {}
	if indep[1] and opts.xrange then
		table.insert(ranges, string.format("{%s, %s, %s}", indep[1], opts.xrange[1], opts.xrange[2]))
	end
	if indep[2] and opts.yrange then
		table.insert(ranges, string.format("{%s, %s, %s}", indep[2], opts.yrange[1], opts.yrange[2]))
	end

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

	return code
end

local function build_implicit_code(opts)
	local series = opts.series or {}
	local exprs = {}
	local has_inequality = false
	for _, s in ipairs(series) do
		if s.kind == "function" or s.kind == "inequality" then
			if s.kind == "inequality" then
				has_inequality = true
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
	apply_series_styles(extra_opts, series)
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
	if #extra_opts > 0 then
		code = code .. ", " .. table.concat(extra_opts, ", ")
	end
	code = code .. "]"

	return code
end

local function build_plot_code(opts)
	if opts.form == "explicit" then
		return build_explicit_code(opts)
	elseif opts.form == "implicit" then
		return build_implicit_code(opts)
	elseif opts.form == "parametric" then
		return build_parametric_code(opts)
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

function M.plot_async(opts, callback)
	opts = opts or {}
	assert(type(callback) == "function", "plot async expects a callback")

	logger.debug("Wolfram plot", "plot_async called")

	if not opts.out_path then
		callback("Missing out_path", nil)
		return
	end

	local plot_code, err = build_plot_code(opts)
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
				local msg = stderr ~= "" and stderr or stdout

				if msg == "" then
					msg = string.format("wolframscript exited with code %d", exit_code)
				end
				if callback then
					callback(msg, nil)
				end
			end
		end,
	})
end

return M
