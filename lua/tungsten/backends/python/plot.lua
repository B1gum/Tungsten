local path = require("pl.path")
local base = require("tungsten.backends.plot_base")
local logger = require("tungsten.util.logger")
local async = require("tungsten.util.async")
local config = require("tungsten.config")
local error_handler = require("tungsten.util.error_handler")
local executor = require("tungsten.backends.python.executor")
local special_function_guard = require("tungsten.backends.python.analyzers.special_function_guard")

local M = setmetatable({}, { __index = base })

local function unsupported_error(message)
	return {
		code = error_handler.E_UNSUPPORTED_FORM,
		message = message,
	}
end

local function normalize_error(err, fallback_code)
	if not err then
		return nil
	end
	if type(err) == "string" then
		return {
			code = fallback_code or error_handler.E_BACKEND_CRASH,
			message = err,
		}
	end
	return err
end

local function render_ast_to_python(ast)
	if not ast then
		return nil
	end
	local ok, code = pcall(executor.ast_to_code, ast)
	if ok then
		return code
	end
	return nil
end

local function to_python_value(value)
	if value == nil or type(value) == "number" then
		return value
	end
	if type(value) == "table" then
		local rendered = render_ast_to_python(value)
		if rendered then
			return rendered
		end
		return tostring(value)
	end
	return value
end

local function normalize_ranges(opts)
	local keys = { "xrange", "yrange", "zrange", "t_range", "u_range", "v_range", "theta_range" }
	for _, key in ipairs(keys) do
		local range = opts and opts[key]
		if type(range) == "table" then
			opts[key] = { to_python_value(range[1]), to_python_value(range[2]) }
		end
	end
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

local function apply_log_mask(lines, axis, var, opts)
	local scale_key = axis .. "scale"
	local scale = opts and opts[scale_key]
	if scale == "log" then
		table.insert(lines, string.format("%s = np.ma.masked_where(%s <= 0, %s)", var, var, var))
	end
end

local function python_string_literal(value)
	if value == nil then
		value = ""
	end
	return string.format("%q", value)
end

local function normalize_legend_position(pos)
	if type(pos) ~= "string" then
		return pos
	end
	local normalized = pos:lower()
	local map = {
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
	return map[normalized] or pos
end

local function build_style_args(series, context, default_color)
	series = series or {}
	local parts = {}
	local color = series.color or default_color
	if color then
		if context == "contour" then
			parts[#parts + 1] = string.format("colors='%s'", color)
		else
			parts[#parts + 1] = string.format("color='%s'", color)
		end
	end
	if series.linewidth then
		if context == "contour" or context == "scatter" then
			parts[#parts + 1] = string.format("linewidths=%s", series.linewidth)
		else
			parts[#parts + 1] = string.format("linewidth=%s", series.linewidth)
		end
	end
	if series.linestyle then
		if context == "contour" then
			parts[#parts + 1] = string.format("linestyles='%s'", series.linestyle)
		else
			parts[#parts + 1] = string.format("linestyle='%s'", series.linestyle)
		end
	end
	if series.marker and context ~= "surface" then
		parts[#parts + 1] = string.format("marker='%s'", series.marker)
	end
	if series.markersize then
		if context == "scatter" then
			parts[#parts + 1] = string.format("s=%s", series.markersize)
		elseif context ~= "surface" then
			parts[#parts + 1] = string.format("markersize=%s", series.markersize)
		end
	elseif context == "scatter" then
		parts[#parts + 1] = "s=1"
	end
	if series.alpha then
		parts[#parts + 1] = string.format("alpha=%s", series.alpha)
	end
	if series.label and (context == "plot" or context == "scatter") then
		parts[#parts + 1] = string.format("label='%s'", series.label)
	end
	if #parts > 0 then
		return ", " .. table.concat(parts, ", ")
	end
	return ""
end

local function build_explicit_2d_python_code(opts)
	local series = opts.series or {}
	local exprs = {}
	local point_series = {}
	for _, s in ipairs(series) do
		if s.kind == "function" then
			local ast = unwrap_equality_rhs(s.ast)
			local code = render_ast_to_python(ast)
			if code then
				table.insert(exprs, { code = code, series = s })
			end
		elseif s.kind == "points" then
			local coords = {}
			for _, p in ipairs(s.points or {}) do
				local x = render_ast_to_python(p.x)
				local y = render_ast_to_python(p.y)
				if x and y then
					coords[#coords + 1] = { x = x, y = y }
				end
			end
			if #coords > 0 then
				point_series[#point_series + 1] = { coords = coords, series = s }
			end
		end
	end
	if #exprs == 0 and #point_series == 0 then
		return nil, nil, unsupported_error("No functions to plot")
	end

	local indep = series[1] and series[1].independent_vars or {}
	local xvar = indep[1] or "x"
	local xrange = opts.xrange or { -10, 10 }
	local samples = opts.samples or 500

	local lines = {}
	table.insert(lines, string.format("%s = sp.symbols('%s')", xvar, xvar))
	table.insert(lines, string.format("xs = np.linspace(%s, %s, %d)", xrange[1], xrange[2], samples))
	apply_log_mask(lines, "x", "xs", opts)
	for i, item in ipairs(exprs) do
		local fname = "f" .. i
		table.insert(lines, string.format("%s = sp.lambdify((%s,), %s, 'numpy')", fname, xvar, item.code))
		local style = build_style_args(item.series, "plot")
		local y_var = string.format("ys%d", i)
		table.insert(lines, string.format("%s = %s(xs)", y_var, fname))
		apply_log_mask(lines, "y", y_var, opts)
		table.insert(lines, string.format("ax.plot(xs, %s%s)", y_var, style))
	end

	for i, points in ipairs(point_series) do
		local xs, ys = {}, {}
		for _, p in ipairs(points.coords) do
			xs[#xs + 1] = p.x
			ys[#ys + 1] = p.y
		end
		local x_name = string.format("x_pts_%d", i)
		local y_name = string.format("y_pts_%d", i)
		table.insert(lines, string.format("%s = np.array([%s], dtype=float)", x_name, table.concat(xs, ", ")))
		table.insert(lines, string.format("%s = np.array([%s], dtype=float)", y_name, table.concat(ys, ", ")))
		apply_log_mask(lines, "x", x_name, opts)
		apply_log_mask(lines, "y", y_name, opts)
		local style = build_style_args(points.series, "scatter")
		table.insert(lines, string.format("ax.scatter(%s, %s%s)", x_name, y_name, style))
	end

	return table.concat(lines, "\n"), nil
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

local function validate_special_function_support(opts)
	local offending
	local function check_ast(ast)
		if offending or not ast then
			return
		end
		local name = special_function_guard.find_disallowed_special_function(ast)
		if name then
			offending = name
		end
	end

	local series = opts.series or {}
	if opts.form == "parametric" then
		for _, s in ipairs(series) do
			if s.kind == "function" and s.ast then
				if opts.dim == 3 then
					check_ast(s.ast.x)
					check_ast(s.ast.y)
					check_ast(s.ast.z)
				else
					check_ast(s.ast.x)
					check_ast(s.ast.y)
				end
			end
			if offending then
				break
			end
		end
	elseif opts.form == "polar" then
		for _, s in ipairs(series) do
			if s.kind == "function" then
				check_ast(extract_polar_expression(s.ast))
			end
			if offending then
				break
			end
		end
	else
		for _, s in ipairs(series) do
			if s.kind == "function" then
				local ast = s.ast
				if opts.form == "explicit" and ast then
					ast = ast.rhs or ast
				end
				check_ast(ast)
			end
			if offending then
				break
			end
		end
	end

	if offending then
		return {
			code = error_handler.E_UNSUPPORTED_FORM,
			message = string.format("Function %s requires SciPy; use Wolfram backend", offending),
		}
	end

	return nil
end

local function build_polar_2d_python_code(opts)
	local series = opts.series or {}
	local exprs = {}
	for _, s in ipairs(series) do
		if s.kind == "function" then
			local expr_ast = extract_polar_expression(s.ast)
			local code = render_ast_to_python(expr_ast)
			if code then
				table.insert(exprs, { code = code, series = s })
			end
		end
	end
	if #exprs == 0 then
		return nil, nil, unsupported_error("No polar functions to plot")
	end

	local indep = series[1] and series[1].independent_vars or {}
	local theta_var = indep[1] or "theta"
	local theta_range = opts.theta_range or { 0, "2*np.pi" }
	local samples = opts.samples or 360
	local theta_vals = theta_var == "theta" and "theta_vals" or (theta_var .. "_vals")

	local lines = {}
	table.insert(lines, string.format("%s = sp.symbols('%s')", theta_var, theta_var))
	table.insert(
		lines,
		string.format("%s = np.linspace(%s, %s, %d)", theta_vals, theta_range[1], theta_range[2], samples)
	)
	for i, item in ipairs(exprs) do
		local fname = "f" .. i
		table.insert(lines, string.format("%s = sp.lambdify((%s,), %s, 'numpy')", fname, theta_var, item.code))
		local style = build_style_args(item.series, "plot")
		table.insert(lines, string.format("ax.plot(%s, %s(%s)%s)", theta_vals, fname, theta_vals, style))
	end

	return table.concat(lines, "\n"), nil
end

local function build_explicit_3d_python_code(opts)
	local series = opts.series or {}
	local exprs = {}
	local point_series = {}
	for _, s in ipairs(series) do
		if s.kind == "function" then
			local ast = unwrap_equality_rhs(s.ast)
			local code = render_ast_to_python(ast)
			if code then
				table.insert(exprs, { code = code, series = s })
			end
		elseif s.kind == "points" then
			local coords = {}
			for _, p in ipairs(s.points or {}) do
				local x = render_ast_to_python(p.x)
				local y = render_ast_to_python(p.y)
				local z = render_ast_to_python(p.z)
				if x and y and z then
					coords[#coords + 1] = { x = x, y = y, z = z }
				end
			end
			if #coords > 0 then
				point_series[#point_series + 1] = { coords = coords, series = s }
			end
		end
	end
	if #exprs == 0 and #point_series == 0 then
		return nil, nil, unsupported_error("No expressions to plot")
	end

	local indep = series[1] and series[1].independent_vars or {}
	local xvar = indep[1] or "x"
	local yvar = indep[2] or "y"
	local xrange = opts.xrange or { -10, 10 }
	local yrange = opts.yrange or { -10, 10 }
	local grid = opts.grid_2d or { 100, 100 }

	local lines = {}
	table.insert(lines, string.format("%s, %s = sp.symbols('%s %s')", xvar, yvar, xvar, yvar))
	table.insert(lines, string.format("x_vals = np.linspace(%s, %s, %d)", xrange[1], xrange[2], grid[1]))
	table.insert(lines, string.format("y_vals = np.linspace(%s, %s, %d)", yrange[1], yrange[2], grid[2]))
	table.insert(lines, "X, Y = np.meshgrid(x_vals, y_vals)")
	apply_log_mask(lines, "x", "X", opts)
	apply_log_mask(lines, "y", "Y", opts)
	local surf_var = "surf"
	for i, item in ipairs(exprs) do
		local fname = "f" .. i
		table.insert(lines, string.format("%s = sp.lambdify((%s,%s), %s, 'numpy')", fname, xvar, yvar, item.code))
		table.insert(lines, string.format("Z = %s(X, Y)", fname))
		apply_log_mask(lines, "z", "Z", opts)
		local style = build_style_args(item.series, "surface")
		table.insert(
			lines,
			string.format("%s = ax.plot_surface(X, Y, Z, cmap='%s'%s)", surf_var, opts.colormap or "viridis", style)
		)
	end

	for i, points in ipairs(point_series) do
		local xs, ys, zs = {}, {}, {}
		for _, p in ipairs(points.coords) do
			xs[#xs + 1] = p.x
			ys[#ys + 1] = p.y
			zs[#zs + 1] = p.z
		end
		local x_name = string.format("x_pts_%d", i)
		local y_name = string.format("y_pts_%d", i)
		local z_name = string.format("z_pts_%d", i)
		table.insert(lines, string.format("%s = np.array([%s], dtype=float)", x_name, table.concat(xs, ", ")))
		table.insert(lines, string.format("%s = np.array([%s], dtype=float)", y_name, table.concat(ys, ", ")))
		table.insert(lines, string.format("%s = np.array([%s], dtype=float)", z_name, table.concat(zs, ", ")))
		apply_log_mask(lines, "x", x_name, opts)
		apply_log_mask(lines, "y", y_name, opts)
		apply_log_mask(lines, "z", z_name, opts)
		local style = build_style_args(points.series, "scatter")
		table.insert(lines, string.format("ax.scatter(%s, %s, %s%s)", x_name, y_name, z_name, style))
	end

	return table.concat(lines, "\n"), surf_var
end

local function build_implicit_2d_py_code(opts)
	local series = opts.series or {}
	local exprs = {}
	for _, s in ipairs(series) do
		if s.kind == "function" then
			local code = render_ast_to_python(s.ast)
			if code then
				table.insert(exprs, { code = code, series = s })
			end
		end
	end
	if #exprs == 0 then
		return nil, nil, unsupported_error("No expressions to plot")
	end

	local indep = series[1] and series[1].independent_vars or {}
	local xvar = indep[1] or "x"
	local yvar = indep[2] or "y"
	local xrange = opts.xrange or { -10, 10 }
	local yrange = opts.yrange or { -10, 10 }
	local grid_n = opts.grid_n or 200

	local lines = {}
	table.insert(lines, string.format("%s, %s = sp.symbols('%s %s')", xvar, yvar, xvar, yvar))
	table.insert(lines, string.format("x_vals = np.linspace(%s, %s, %d)", xrange[1], xrange[2], grid_n))
	table.insert(lines, string.format("y_vals = np.linspace(%s, %s, %d)", yrange[1], yrange[2], grid_n))
	table.insert(lines, "X, Y = np.meshgrid(x_vals, y_vals)")
	apply_log_mask(lines, "x", "X", opts)
	apply_log_mask(lines, "y", "Y", opts)
	local cont_var = "cs"
	for i, item in ipairs(exprs) do
		local fname = "f" .. i
		table.insert(lines, string.format("%s = sp.lambdify((%s,%s), %s, 'numpy')", fname, xvar, yvar, item.code))
		table.insert(lines, string.format("Z = %s(X, Y)", fname))
		local style = build_style_args(item.series, "contour", "black")
		table.insert(lines, string.format("%s = ax.contour(X, Y, Z, levels=[0]%s)", cont_var, style))
	end

	return table.concat(lines, "\n"), cont_var
end

local function build_parametric_2d_py_code(opts)
	local series = opts.series or {}
	local exprs = {}
	for _, s in ipairs(series) do
		if s.kind == "function" and s.ast then
			local x = render_ast_to_python(s.ast.x)
			local y = render_ast_to_python(s.ast.y)
			if x and y then
				table.insert(exprs, { x = x, y = y, indep = s.independent_vars or {}, series = s })
			end
		end
	end
	if #exprs == 0 then
		return nil, nil, unsupported_error("No parametric expressions")
	end

	local tvar = exprs[1].indep[1] or "t"
	local t_range = opts.t_range or { 0, 1 }
	local samples = opts.samples or 300

	local lines = {}
	table.insert(lines, string.format("%s = sp.symbols('%s')", tvar, tvar))
	table.insert(lines, string.format("t_vals = np.linspace(%s, %s, %d)", t_range[1], t_range[2], samples))

	for i, e in ipairs(exprs) do
		local fx = "fx" .. i
		local fy = "fy" .. i
		table.insert(lines, string.format("%s = sp.lambdify((%s,), %s, 'numpy')", fx, tvar, e.x))
		table.insert(lines, string.format("%s = sp.lambdify((%s,), %s, 'numpy')", fy, tvar, e.y))
		local style = build_style_args(e.series, "plot")
		local x_var = string.format("x_vals_%d", i)
		local y_var = string.format("y_vals_%d", i)
		table.insert(lines, string.format("%s = %s(t_vals)", x_var, fx))
		apply_log_mask(lines, "x", x_var, opts)
		table.insert(lines, string.format("%s = %s(t_vals)", y_var, fy))
		apply_log_mask(lines, "y", y_var, opts)
		table.insert(lines, string.format("ax.plot(%s, %s%s)", x_var, y_var, style))
	end

	return table.concat(lines, "\n"), nil
end

local function build_parametric_3d_py_code(opts)
	local series = opts.series or {}
	local exprs = {}
	for _, s in ipairs(series) do
		if s.kind == "function" and s.ast then
			local x = render_ast_to_python(s.ast.x)
			local y = render_ast_to_python(s.ast.y)
			local z = render_ast_to_python(s.ast.z)
			if x and y and z then
				table.insert(exprs, { x = x, y = y, z = z, series = s })
			end
		end
	end
	if #exprs == 0 then
		return nil, nil, unsupported_error("No parametric expressions")
	end

	local indep = series[1] and series[1].independent_vars or {}
	local uvar = indep[1] or "u"
	local vvar = indep[2] or "v"
	local u_range = opts.u_range or { 0, 1 }
	local v_range = opts.v_range or { 0, 1 }
	local grid = opts.grid_3d or { 64, 64 }

	local lines = {}
	table.insert(lines, string.format("%s, %s = sp.symbols('%s %s')", uvar, vvar, uvar, vvar))
	table.insert(lines, string.format("u_vals = np.linspace(%s, %s, %d)", u_range[1], u_range[2], grid[1]))
	table.insert(lines, string.format("v_vals = np.linspace(%s, %s, %d)", v_range[1], v_range[2], grid[2]))
	table.insert(lines, "U, V = np.meshgrid(u_vals, v_vals)")
	local surf_var = "surf"
	for i, e in ipairs(exprs) do
		local fx = "fx" .. i
		local fy = "fy" .. i
		local fz = "fz" .. i
		table.insert(lines, string.format("%s = sp.lambdify((%s,%s), %s, 'numpy')", fx, uvar, vvar, e.x))
		table.insert(lines, string.format("%s = sp.lambdify((%s,%s), %s, 'numpy')", fy, uvar, vvar, e.y))
		table.insert(lines, string.format("%s = sp.lambdify((%s,%s), %s, 'numpy')", fz, uvar, vvar, e.z))
		table.insert(lines, string.format("X = %s(U, V)", fx))
		apply_log_mask(lines, "x", "X", opts)
		table.insert(lines, string.format("Y = %s(U, V)", fy))
		apply_log_mask(lines, "y", "Y", opts)
		table.insert(lines, string.format("Z = %s(U, V)", fz))
		apply_log_mask(lines, "z", "Z", opts)
		local style = build_style_args(e.series, "surface")
		table.insert(
			lines,
			string.format("%s = ax.plot_surface(X, Y, Z, cmap='%s'%s)", surf_var, opts.colormap or "viridis", style)
		)
	end

	return table.concat(lines, "\n"), surf_var
end

function M.build_plot_code(opts)
	local guard_err = validate_special_function_support(opts)
	if guard_err then
		return nil, nil, guard_err
	end

	normalize_ranges(opts)

	if opts.form == "explicit" then
		if opts.dim == 3 then
			return build_explicit_3d_python_code(opts)
		else
			return build_explicit_2d_python_code(opts)
		end
	elseif opts.form == "polar" then
		return build_polar_2d_python_code(opts)
	elseif opts.form == "implicit" then
		if opts.dim == 3 then
			return nil,
				nil,
				{
					code = error_handler.E_UNSUPPORTED_FORM,
					message = "Implicit 3D plots are not supported by the Python backend",
				}
		else
			return build_implicit_2d_py_code(opts)
		end
	elseif opts.form == "parametric" then
		if opts.dim == 3 then
			return build_parametric_3d_py_code(opts)
		else
			return build_parametric_2d_py_code(opts)
		end
	end
	return nil, nil, unsupported_error("Unsupported plot form")
end

function M.build_python_script(opts)
	local plot_code, colorbar_var, err = M.build_plot_code(opts)
	if not plot_code then
		return nil, err
	end

	local plotting_defaults = config.plotting or {}

	local function get_or_default(val, fallback)
		if val == nil then
			return fallback
		end
		return val
	end

	local usetex = get_or_default(opts.usetex, plotting_defaults.usetex)
	if usetex == nil then
		usetex = false
	end
	local latex_engine = get_or_default(opts.latex_engine, plotting_defaults.latex_engine)
	local latex_preamble = get_or_default(opts.latex_preamble, plotting_defaults.latex_preamble)
	if latex_preamble == nil then
		latex_preamble = ""
	end

	local lines = {
		"import os",
		"os.environ['MPLBACKEND'] = 'Agg'",
		"import matplotlib",
		"matplotlib.use('Agg')",
		string.format("matplotlib.rcParams['text.usetex'] = %s", usetex and "True" or "False"),
		string.format("matplotlib.rcParams['text.latex.preamble'] = %s", python_string_literal(latex_preamble)),
		"import matplotlib.pyplot as plt",
		"import numpy as np",
		"import sympy as sp",
		"from mpl_toolkits.mplot3d import Axes3D",
		"fig = plt.figure()",
	}

	if latex_engine and latex_engine ~= "" then
		table.insert(
			lines,
			5,
			string.format("matplotlib.rcParams['pgf.texsystem'] = %s", python_string_literal(latex_engine))
		)
		if latex_engine == "pdflatex" then
			table.insert(lines, "texinputs = os.environ.get('TEXINPUTS', '')")
			table.insert(lines, "if texinputs and not texinputs.endswith(os.pathsep):")
			table.insert(lines, "    texinputs = texinputs + os.pathsep")
			table.insert(lines, "os.environ['TEXINPUTS'] = texinputs")
		end
	end
	if opts.form == "polar" then
		table.insert(lines, "ax = fig.add_subplot(111, projection='polar')")
	elseif opts.dim == 3 then
		table.insert(lines, "ax = fig.add_subplot(111, projection='3d')")
	else
		table.insert(lines, "ax = fig.add_subplot(111)")
	end

	table.insert(lines, plot_code)

	if opts.xscale then
		table.insert(lines, string.format("ax.set_xscale('%s')", opts.xscale))
	end
	if opts.yscale then
		table.insert(lines, string.format("ax.set_yscale('%s')", opts.yscale))
	end
	if opts.zscale and opts.dim == 3 then
		table.insert(lines, string.format("ax.set_zscale('%s')", opts.zscale))
	end

	if opts.figsize_in then
		table.insert(lines, string.format("fig.set_size_inches(%s, %s)", opts.figsize_in[1], opts.figsize_in[2]))
	end
	if opts.bg_color then
		table.insert(lines, string.format("fig.patch.set_facecolor('%s')", opts.bg_color))
		table.insert(lines, string.format("ax.set_facecolor('%s')", opts.bg_color))
	end
	if opts.grids ~= nil then
		table.insert(lines, string.format("ax.grid(%s)", opts.grids and "True" or "False"))
	end
	if opts.xrange then
		table.insert(lines, string.format("ax.set_xlim(%s, %s)", opts.xrange[1], opts.xrange[2]))
	end
	if opts.yrange then
		table.insert(lines, string.format("ax.set_ylim(%s, %s)", opts.yrange[1], opts.yrange[2]))
	end
	if opts.zrange and opts.dim == 3 then
		table.insert(lines, string.format("ax.set_zlim(%s, %s)", opts.zrange[1], opts.zrange[2]))
	end
	if opts.aspect == "equal" and opts.dim ~= 3 then
		table.insert(lines, "ax.set_aspect('equal', adjustable='box')")
	end
	if opts.view_elev or opts.view_azim then
		local elev = opts.view_elev or 30
		local azim = opts.view_azim or -60
		table.insert(lines, string.format("ax.view_init(elev=%s, azim=%s)", elev, azim))
	end
	if opts.colorbar and colorbar_var then
		table.insert(lines, string.format("fig.colorbar(%s, ax=ax)", colorbar_var))
	end

	local has_labels = false
	if not (opts.dim == 3 and (opts.form == "explicit" or opts.form == "parametric")) then
		for _, s in ipairs(opts.series or {}) do
			if s.label and s.label ~= "" then
				has_labels = true
				break
			end
		end
	end
	if has_labels then
		local legend_pos = normalize_legend_position(opts.legend_pos)
		if opts.legend_auto == false then
			if legend_pos then
				table.insert(lines, string.format("ax.legend(loc='%s')", legend_pos))
			end
		elseif legend_pos then
			table.insert(lines, string.format("ax.legend(loc='%s')", legend_pos))
		else
			table.insert(lines, "ax.legend()")
		end
	end

	local out_path = opts.out_path
	if not out_path:match("%.%w+$") then
		out_path = out_path .. "." .. (opts.format or "png")
	end
	local dpi = opts.dpi or 100
	if opts.crop then
		table.insert(
			lines,
			string.format("plt.savefig(r'%s', dpi=%d, bbox_inches='tight', pad_inches=0.02)", out_path, dpi)
		)
	else
		table.insert(lines, string.format("plt.savefig(r'%s', dpi=%d)", out_path, dpi))
	end
	table.insert(lines, string.format("print(r'%s')", out_path))

	return table.concat(lines, "\n")
end

function M.plot_async(opts, callback)
	local normalized_opts, err = M.prepare_opts(opts, callback)
	if not normalized_opts then
		callback(err, nil)
		return
	end

	logger.debug("Python plot", "plot_async called")

	local script, build_err = M.build_python_script(normalized_opts)
	if not script then
		local normalized_err = normalize_error(build_err, error_handler.E_UNSUPPORTED_FORM)
		callback(normalized_err or {
			code = error_handler.E_BACKEND_CRASH,
			message = "Failed to build plot code",
		}, nil)
		return
	end

	local python_opts = config.backend_opts and config.backend_opts.python or {}
	local python_path = python_opts.python_path or "python3"

	local cwd
	if normalized_opts.tex_root and normalized_opts.tex_root ~= "" then
		if path.isdir(normalized_opts.tex_root) then
			cwd = normalized_opts.tex_root
		else
			cwd = path.dirname(normalized_opts.tex_root)
		end
	elseif normalized_opts.out_path and normalized_opts.out_path ~= "" then
		cwd = path.dirname(normalized_opts.out_path)
	end

	async.run_job({ python_path, "-c", script }, {
		timeout = normalized_opts.timeout_ms,
		cwd = cwd,
		on_exit = function(exit_code, stdout, stderr)
			if exit_code == 0 then
				local trimmed
				if type(stdout) == "string" then
					trimmed = stdout:match("^%s*(.-)%s*$")
					if trimmed == "" then
						trimmed = nil
					end
				end
				local out_path = normalized_opts.out_path
				if callback then
					callback(nil, trimmed or out_path)
				end
			else
				local msg = stderr ~= "" and stderr or stdout
				if msg == "" then
					msg = string.format("python exited with code %d", exit_code)
				end
				local error_payload = normalize_error(msg, error_handler.E_BACKEND_CRASH)
				if callback then
					callback(error_payload, nil)
				end
			end
		end,
	})
end

return M
