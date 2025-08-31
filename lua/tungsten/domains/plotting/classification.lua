local M = {}

local free_vars = require("tungsten.domains.plotting.free_vars")

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
		if opts and opts.simple_mode then
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

local function analyze_equality(ast, opts)
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
	if ast.type == "equality" then
		return analyze_equality(ast, opts)
	elseif ast.type == "Parametric2D" or ast.type == "parametric_2d" then
    return analyze_parametric2d(ast)
  elseif ast.type == "Parametric3D" or ast.type == "parametric_3d" then
    return analyze_parametric3d(ast)
  elseif ast.type == "Polar2D" or ast.type == "polar_2d" then
    return analyze_polar2d(ast)
  else
    return analyze_expression(ast, opts)
	end
end

return M
