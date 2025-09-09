local M = {}

local free_vars = require("tungsten.domains.plotting.free_vars")
local helpers = require("tungsten.domains.plotting.helpers")

local function find_free_variables(node)
	return free_vars.find(node)
end

local function union_vars(...)
	local set = {}
	local result = {}
	for _, vars in ipairs({ ... }) do
		for _, v in ipairs(vars) do
			if not set[v] then
				set[v] = true
				table.insert(result, v)
			end
		end
	end
	table.sort(result)
	return result
end

local function is_simple_variable(node)
	if type(node) == "table" and node.type == "variable" then
		return true, node.name
	end
	return false, nil
end

local function analyze_point2(point, opts)
	opts = opts or {}
	if opts.mode == "advanced" then
		if opts.form == "parametric" then
			local param = helpers.detect_point2_param(point)
			if not param then
				return nil, { code = "E_MIXED_COORD_SYS" }
			end
			local params = union_vars(find_free_variables(point.x), find_free_variables(point.y))
			return {
				dim = 2,
				form = "parametric",
				series = {
					{
						kind = "function",
						ast = point,
						independent_vars = params,
						dependent_vars = { "x", "y" },
					},
				},
			}
		elseif opts.form == "polar" then
			if not (point.y and point.y.type == "variable" and point.y.name == "theta") then
				return nil, { code = "E_MIXED_COORD_SYS" }
			end
			local x_params = helpers.extract_param_names(point.x)
			for _, p in ipairs(x_params) do
				if p ~= "theta" then
					return nil, { code = "E_MIXED_COORD_SYS" }
				end
			end
			local params = union_vars(find_free_variables(point.x), find_free_variables(point.y))
			return {
				dim = 2,
				form = "polar",
				series = {
					{
						kind = "function",
						ast = point,
						independent_vars = params,
						dependent_vars = { "r" },
					},
				},
			}
		end
	end
	return {
		dim = 2,
		form = "explicit",
		series = { { kind = "points", points = { point } } },
	}
end

local function analyze_sequence(ast, opts)
	local nodes = ast.nodes or {}
	if #nodes == 0 then
		for _, n in ipairs(ast) do
			table.insert(nodes, n)
		end
	end
	local series = {}
	local dim, form

	local i = 1
	while i <= #nodes do
		local node = nodes[i]
		local t = node.type
		local treat_as_points = (t == "Point2" or t == "point_2d" or t == "Point3" or t == "point_3d")
			and not (opts.mode == "advanced" and (opts.form == "parametric" or opts.form == "polar"))
		if treat_as_points then
			local points = { node }
			local pdim = (t == "Point3" or t == "point_3d") and 3 or 2
			i = i + 1
			while i <= #nodes do
				local nxt = nodes[i]
				local nt = nxt.type
				local is_same = (pdim == 2 and (nt == "Point2" or nt == "point_2d"))
					or (pdim == 3 and (nt == "Point3" or nt == "point3d"))
				if not is_same then
					break
				end
				table.insert(points, nxt)
				i = i + 1
			end

			if dim and dim ~= pdim then
				return nil, { code = "E_MIXED_DIMENSIONS" }
			end
			if form and form ~= "explicit" then
				return nil, { code = "E_MIXED_COORD_SYS" }
			end
			dim = pdim
			form = "explicit"
			table.insert(series, { kind = "points", points = points })
		else
			local sub, err = M.analyze(node, opts)
			if not sub then
				return nil, err
			end
			if dim and dim ~= sub.dim then
				return nil, { code = "E_MIXED_DIMENSIONS" }
			end
			if form and form ~= sub.form then
				return nil, { code = "E_MIXED_COORD_SYS" }
			end
			dim = sub.dim
			form = sub.form
			for _, s in ipairs(sub.series) do
				table.insert(series, s)
			end
			i = i + 1
		end
	end

	return { dim = dim, form = form, series = series }
end

local function analyze_expression(ast, opts)
	local vars = find_free_variables(ast)
	local result = {
		series = {
			{
				kind = "function",
				ast = ast,
				independent_vars = vars,
				dependent_vars = {},
			},
		},
	}

	if #vars == 1 then
		result.dim = 2
		result.form = "explicit"
		result.series[1].dependent_vars = { "y" }
	elseif #vars == 2 then
		if opts and (opts.simple_mode or opts.mode == "simple") then
			result.dim = 2
			result.form = "implicit"
		else
			result.dim = 3
			result.form = "explicit"
			result.series[1].dependent_vars = { "z" }
		end
	else
		result.dim = #vars + 1
		result.form = "explicit"
	end

	return result
end

local function analyze_parametric2d(ast)
	local params = union_vars(find_free_variables(ast.x), find_free_variables(ast.y))
	return {
		dim = 2,
		form = "parametric",
		series = {
			{
				kind = "function",
				ast = ast,
				independent_vars = params,
				dependent_vars = { "x", "y" },
			},
		},
	}
end

local function analyze_parametric3d(ast)
	local params = union_vars(find_free_variables(ast.x), find_free_variables(ast.y), find_free_variables(ast.z))
	return {
		dim = 3,
		form = "parametric",
		series = {
			{
				kind = "function",
				ast = ast,
				independent_vars = params,
				dependent_vars = { "x", "y", "z" },
			},
		},
	}
end

local function analyze_polar2d(ast)
	local params = find_free_variables(ast.r)
	return {
		dim = 2,
		form = "polar",
		series = {
			{
				kind = "function",
				ast = ast,
				independent_vars = params,
				dependent_vars = { "r" },
			},
		},
	}
end

local function analyze_inequality(ast)
	local free = find_free_variables(ast)
	return {
		dim = #free,
		form = "implicit",
		series = {
			{
				kind = "function",
				ast = ast,
				independent_vars = free,
				dependent_vars = {},
			},
		},
	}
end

local function analyze_equality(ast)
	local lhs_is_var, lhs_var = is_simple_variable(ast.lhs)
	if lhs_is_var and (lhs_var == "y" or lhs_var == "z") then
		local free = find_free_variables(ast.rhs)
		local dim = #free + 1
		return {
			dim = dim,
			form = "explicit",
			series = {
				{
					kind = "function",
					ast = ast,
					independent_vars = free,
					dependent_vars = { lhs_var },
				},
			},
		}
	else
		local free = find_free_variables(ast)
		return {
			dim = #free,
			form = "implicit",
			series = {
				{
					kind = "function",
					ast = ast,
					independent_vars = free,
					dependent_vars = {},
				},
			},
		}
	end
end

function M.analyze(ast, opts)
	opts = opts or {}
	local t = ast.type
	if t == "Sequence" or t == "sequence" then
		return analyze_sequence(ast, opts)
	elseif t == "equality" or t == "Equality" then
		return analyze_equality(ast)
	elseif t == "Parametric2D" or t == "parametric_2d" then
		return analyze_parametric2d(ast)
	elseif t == "Parametric3D" or t == "parametric_3d" then
		return analyze_parametric3d(ast)
	elseif t == "Polar2D" or t == "polar_2d" then
		return analyze_polar2d(ast)
	elseif t == "inequality" or t == "Inequality" then
		return analyze_inequality(ast)
	elseif t == "Point2" or t == "point_2d" then
		return analyze_point2(ast, opts)
	else
		return analyze_expression(ast, opts)
	end
end

return M
