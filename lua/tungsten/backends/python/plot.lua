local base = require("tungsten.backends.plot_base")
local logger = require("tungsten.util.logger")
local async = require("tungsten.util.async")
local config = require("tungsten.config")
local executor = require("tungsten.backends.python.executor")

local M = setmetatable({}, { __index = base })

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
	for _, s in ipairs(series) do
		if s.kind == "function" then
			local ast = s.ast
			if ast and ast.type == "equality" and ast.rhs then
				ast = ast.rhs
			end
			local code = render_ast_to_python(ast)
			if code then
				table.insert(exprs, { code = code, series = s })
			end
		end
	end
	if #exprs == 0 then
		return nil, nil, "No functions to plot"
	end

	local indep = series[1] and series[1].independent_vars or {}
	local xvar = indep[1] or "x"
	local xrange = opts.xrange or { -10, 10 }
	local samples = opts.samples or 500

	local lines = {}
	table.insert(lines, string.format("%s = sp.symbols('%s')", xvar, xvar))
	table.insert(lines, string.format("xs = np.linspace(%s, %s, %d)", xrange[1], xrange[2], samples))
	for i, item in ipairs(exprs) do
		local fname = "f" .. i
		table.insert(lines, string.format("%s = sp.lambdify((%s,), %s, 'numpy')", fname, xvar, item.code))
		local style = build_style_args(item.series, "plot")
		table.insert(lines, string.format("ax.plot(xs, %s(xs)%s)", fname, style))
	end

	return table.concat(lines, "\n"), nil
end

local function build_explicit_3d_python_code(opts)
	local series = opts.series or {}
	local exprs = {}
	for _, s in ipairs(series) do
		if s.kind == "function" then
			local ast = s.ast
			if ast and ast.type == "equality" and ast.rhs then
				ast = ast.rhs
			end
			local code = render_ast_to_python(ast)
			if code then
				table.insert(exprs, { code = code, series = s })
			end
		end
	end
	if #exprs == 0 then
		return nil, nil, "No functions to plot"
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
	local surf_var = "surf"
	for i, item in ipairs(exprs) do
		local fname = "f" .. i
		table.insert(lines, string.format("%s = sp.lambdify((%s,%s), %s, 'numpy')", fname, xvar, yvar, item.code))
		table.insert(lines, string.format("Z = %s(X, Y)", fname))
		local style = build_style_args(item.series, "surface")
		table.insert(
			lines,
			string.format("%s = ax.plot_surface(X, Y, Z, cmap='%s'%s)", surf_var, opts.colormap or "viridis", style)
		)
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
		return nil, nil, "No expressions to plot"
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

local function build_implicit_3d_py_code(opts)
	local series = opts.series or {}
	local expr
	for _, s in ipairs(series) do
		if s.kind == "function" then
			expr = render_ast_to_python(s.ast)
			if expr then
				break
			end
		end
	end
	if not expr then
		return nil, nil, "No expressions to plot"
	end

	local indep = series[1] and series[1].independent_vars or {}
	local xvar = indep[1] or "x"
	local yvar = indep[2] or "y"
	local zvar = indep[3] or "z"
	local xrange = opts.xrange or { -10, 10 }
	local yrange = opts.yrange or { -10, 10 }
	local zrange = opts.zrange or { -10, 10 }
	local vol = opts.vol_3d or { 30, 30, 30 }

	local lines = {}
	table.insert(lines, string.format("%s, %s, %s = sp.symbols('%s %s %s')", xvar, yvar, zvar, xvar, yvar, zvar))
	table.insert(lines, string.format("x_vals = np.linspace(%s, %s, %d)", xrange[1], xrange[2], vol[1]))
	table.insert(lines, string.format("y_vals = np.linspace(%s, %s, %d)", yrange[1], yrange[2], vol[2]))
	table.insert(lines, string.format("z_vals = np.linspace(%s, %s, %d)", zrange[1], zrange[2], vol[3]))
	table.insert(lines, "X, Y, Z = np.meshgrid(x_vals, y_vals, z_vals)")
	table.insert(lines, string.format("f = sp.lambdify((%s,%s,%s), %s, 'numpy')", xvar, yvar, zvar, expr))
	table.insert(lines, "vals = f(X, Y, Z)")
	table.insert(lines, "mask = np.isclose(vals, 0, atol=0.1)")
	local style = build_style_args(series[1], "scatter")
	table.insert(lines, string.format("ax.scatter(X[mask], Y[mask], Z[mask]%s)", style))

	return table.concat(lines, "\n"), nil
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
		return nil, nil, "No parametric expressions"
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
		table.insert(lines, string.format("ax.plot(%s(t_vals), %s(t_vals)%s)", fx, fy, style))
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
		return nil, nil, "No parametric expressions"
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
		table.insert(lines, string.format("Y = %s(U, V)", fy))
		table.insert(lines, string.format("Z = %s(U, V)", fz))
		local style = build_style_args(e.series, "surface")
		table.insert(
			lines,
			string.format("%s = ax.plot_surface(X, Y, Z, cmap='%s'%s)", surf_var, opts.colormap or "viridis", style)
		)
	end

	return table.concat(lines, "\n"), surf_var
end

local function build_plot_code(opts)
	if opts.form == "explicit" then
		if opts.dim == 3 then
			return build_explicit_3d_python_code(opts)
		else
			return build_explicit_2d_python_code(opts)
		end
	elseif opts.form == "implicit" then
		if opts.dim == 3 then
			return build_implicit_3d_py_code(opts)
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
	return nil, nil, "Unsupported plot form"
end

local function build_python_script(opts)
	local plot_code, colorbar_var, err = build_plot_code(opts)
	if not plot_code then
		return nil, err
	end

	local lines = {
		"import os",
		"os.environ['MPLBACKEND'] = 'Agg'",
		"import matplotlib",
		"matplotlib.use('Agg')",
		"import matplotlib.pyplot as plt",
		"import numpy as np",
		"import sympy as sp",
		"from mpl_toolkits.mplot3d import Axes3D",
		"fig = plt.figure()",
	}
	if opts.dim == 3 then
		table.insert(lines, "ax = fig.add_subplot(111, projection='3d')")
	else
		table.insert(lines, "ax = fig.add_subplot(111)")
	end

	table.insert(lines, plot_code)

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
		if opts.legend_auto == false and opts.legend_pos then
			table.insert(lines, string.format("ax.legend(loc='%s')", opts.legend_pos))
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

	return table.concat(lines, "\n")
end

function M.plot_async(opts, callback)
	opts = opts or {}
	assert(type(callback) == "function", "plot async expects a callback")

	logger.debug("Python plot", "plot_async called")

	if not opts.out_path then
		callback("Missing out_path", nil)
		return
	end

	local script, err = build_python_script(opts)
	if not script then
		callback(err or "Failed to build plot code", nil)
		return
	end

	local python_opts = config.backend_opts and config.backend_opts.python or {}
	local python_path = python_opts.python_path or "python3"

	async.run_job({ python_path, "-c", script }, {
		timeout = opts.timeout_ms,
		on_exit = function(exit_code, stdout, stderr)
			if exit_code == 0 then
				if callback then
					callback(nil, stdout)
				end
			else
				local msg = stderr ~= "" and stderr or stdout
				if msg == "" then
					msg = string.format("python exited with code %d", exit_code)
				end
				if callback then
					callback(msg, nil)
				end
			end
		end,
	})
end

return M
