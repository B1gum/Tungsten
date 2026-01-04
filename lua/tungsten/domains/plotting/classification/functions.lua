local ast_builder = require("tungsten.core.ast")
local error_handler = require("tungsten.util.error_handler")
local util = require("tungsten.domains.plotting.classification.util")

local M = {}

local function is_simple_variable(node)
	if type(node) == "table" and node.type == "variable" then
		return true, node.name
	end
	return false, nil
end

local function is_function_call_with_args(node)
	if type(node) == "table" and node.type == "function_call" then
		local args = node.args or {}
		if #args > 0 then
			local name = node.name
			if not name and node.name_node then
				name = node.name_node.name
			end
			return true, name
		end
	end
	return false, nil
end

function M.analyze_expression(ast_node, opts)
	local vars = util.find_free_variables(ast_node)
	if opts and (opts.simple_mode or opts.mode == "simple") and #vars == 1 and vars[1] == "theta" then
		local polar = ast_builder.create_polar2d_node(ast_node)
		return M.analyze_polar2d(polar)
	end

	local result = {
		series = {
			{
				kind = "function",
				ast = ast_node,
				independent_vars = vars,
				dependent_vars = {},
			},
		},
	}

	if #vars == 1 then
		result.dim = 2
		result.form = "explicit"
		if vars[1] == "y" then
			result.series[1].dependent_vars = { "x" }
		else
			result.series[1].dependent_vars = { "y" }
		end
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

function M.analyze_parametric2d(ast)
	local params = util.union_vars(util.find_free_variables(ast.x), util.find_free_variables(ast.y))
	if #params ~= 1 then
		return nil,
			{
				code = error_handler.E_MIXED_COORD_SYS,
				message = "Parametric 2D plots require exactly one parameter.",
			}
	end
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

function M.analyze_parametric3d(ast)
	local params =
		util.union_vars(util.find_free_variables(ast.x), util.find_free_variables(ast.y), util.find_free_variables(ast.z))
	if #params < 1 or #params > 2 then
		return nil,
			{
				code = error_handler.E_MIXED_COORD_SYS,
				message = "Parametric 3D plots require one or two parameters.",
			}
	end
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

function M.analyze_polar2d(ast)
	local params = util.find_free_variables(ast.r)
	if #params ~= 1 or params[1] ~= "theta" then
		return nil,
			{
				code = error_handler.E_MIXED_COORD_SYS,
				message = "Polar plots require theta as the independent variable.",
			}
	end
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

function M.analyze_inequality(ast)
	local free = util.find_free_variables(ast)
	return {
		dim = #free,
		form = "implicit",
		series = {
			{
				kind = "inequality",
				ast = ast,
				independent_vars = free,
				dependent_vars = {},
			},
		},
	}
end

function M.analyze_equality(ast_node, opts)
	if opts and (opts.simple_mode or opts.mode == "simple") then
		local lhs_is_var, lhs_var = is_simple_variable(ast_node.lhs)
		if lhs_is_var and lhs_var == "r" then
			local rhs_vars = util.find_free_variables(ast_node.rhs)
			if #rhs_vars == 1 and rhs_vars[1] == "theta" then
				local polar = ast_builder.create_polar2d_node(ast_node.rhs)
				return M.analyze_polar2d(polar)
			end
		end
	end

	local lhs_is_call, lhs_name = is_function_call_with_args(ast_node.lhs)
	if lhs_is_call then
		local free = util.find_free_variables(ast_node.rhs)
		if util.remove_var(free, lhs_name) then
			free = util.find_free_variables(ast_node)
			util.remove_var(free, lhs_name)
			return {
				dim = #free,
				form = "implicit",
				series = {
					{ kind = "function", ast = ast_node, independent_vars = free, dependent_vars = {} },
				},
			}
		end
		local dim = #free + 1
		dim = math.max(2, dim)
		return {
			dim = dim,
			form = "explicit",
			series = {
				{
					kind = "function",
					ast = ast_node,
					independent_vars = free,
					dependent_vars = { lhs_name },
				},
			},
		}
	end
	local lhs_is_var, lhs_var = is_simple_variable(ast_node.lhs)
	if lhs_is_var and lhs_var == "x" then
		local free = util.find_free_variables(ast_node.rhs)
		if util.remove_var(free, lhs_var) then
			free = util.find_free_variables(ast_node)
			util.remove_var(free, lhs_var)
			return {
				dim = #free,
				form = "implicit",
				series = {
					{ kind = "function", ast = ast_node, independent_vars = free, dependent_vars = {} },
				},
			}
		end
		local dim = #free + 1
		dim = math.max(2, dim)
		return {
			dim = dim,
			form = "explicit",
			series = {
				{
					kind = "function",
					ast = ast_node,
					independent_vars = free,
					dependent_vars = { "x" },
				},
			},
		}
	elseif lhs_is_var and (lhs_var == "y" or lhs_var == "z") then
		local free = util.find_free_variables(ast_node.rhs)
		if util.remove_var(free, lhs_var) then
			free = util.find_free_variables(ast_node)
			util.remove_var(free, lhs_var)
			return {
				dim = #free,
				form = "implicit",
				series = {
					{ kind = "function", ast = ast_node, independent_vars = free, dependent_vars = {} },
				},
			}
		end
		local dim = #free + 1
		if lhs_var == "z" then
			dim = math.max(3, dim)
		else
			dim = math.max(2, dim)
		end
		return {
			dim = dim,
			form = "explicit",
			series = {
				{
					kind = "function",
					ast = ast_node,
					independent_vars = free,
					dependent_vars = { lhs_var },
				},
			},
		}
	else
		local free = util.find_free_variables(ast_node)
		return {
			dim = #free,
			form = "implicit",
			series = {
				{
					kind = "function",
					ast = ast_node,
					independent_vars = free,
					dependent_vars = {},
				},
			},
		}
	end
end

return M
