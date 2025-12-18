-- lua/tungsten/domains/calculus/wolfram_handlers.lua
-- Wolfram Language handlers for calculus operations
---------------------------------------------------------------------

local M = {}
local constants = require("tungsten.core.constants")

local function map_function_name(func_name_str)
	local wolfram_opts = (require("tungsten.config").backend_opts or {}).wolfram or {}
	local func_name_map = wolfram_opts.function_mappings or {}
	local mapped = func_name_map[func_name_str:lower()]

	if not mapped then
		mapped = func_name_str:match("^%a") and (func_name_str:sub(1, 1):upper() .. func_name_str:sub(2)) or func_name_str
	end

	return mapped
end

M.handlers = {
	ordinary_derivative = function(node, walk)
		local variable_str = walk(node.variable)
		local numeric_order = node.order and node.order.value
		local order_str = (node.order and walk(node.order)) or "1"

		if
			node.expression
			and node.expression.type == "function_call"
			and numeric_order
			and type(numeric_order) == "number"
		then
			local func_name = node.expression.name_node and node.expression.name_node.name
			local arg_str = node.expression.args and node.expression.args[1] and walk(node.expression.args[1]) or variable_str
			local prime_str = string.rep("'", numeric_order)
			return map_function_name(func_name or "") .. prime_str .. "[" .. arg_str .. "]"
		end

		local expression_str = walk(node.expression)

		if tostring(order_str) == "1" then
			return "D[" .. expression_str .. ", " .. variable_str .. "]"
		end

		return "D[" .. expression_str .. ", {" .. variable_str .. ", " .. tostring(order_str) .. "}]"
	end,

	partial_derivative = function(node, recur_render)
		local expr_str = recur_render(node.expression)
		local vars_rendered = {}

		for _, var_node_info in ipairs(node.variables) do
			local var_name_str = recur_render(var_node_info.variable)
			local var_order_str = recur_render(var_node_info.order)
			if var_order_str == "1" then
				table.insert(vars_rendered, var_name_str)
			else
				table.insert(vars_rendered, ("{%s, %s}"):format(var_name_str, var_order_str))
			end
		end

		return ("D[%s, %s]"):format(expr_str, table.concat(vars_rendered, ", "))
	end,

	limit = function(node, recur_render)
		local expr_str = recur_render(node.expression)
		local var_str = recur_render(node.variable)
		local point_str = recur_render(node.point)
		return ("Limit[%s, %s -> %s]"):format(expr_str, var_str, point_str)
	end,

	indefinite_integral = function(node, recur_render)
		local integrand_str = recur_render(node.integrand)
		local var_str = recur_render(node.variable)
		return ("Integrate[%s, %s]"):format(integrand_str, var_str)
	end,

	definite_integral = function(node, recur_render)
		local integrand_str = recur_render(node.integrand)
		local var_str = recur_render(node.variable)
		local lower_bound_str = recur_render(node.lower_bound)
		local upper_bound_str = recur_render(node.upper_bound)
		return ("Integrate[%s, {%s, %s, %s}]"):format(integrand_str, var_str, lower_bound_str, upper_bound_str)
	end,

	summation = function(node, recur_render)
		local body_str = recur_render(node.body_expression)
		local index_var_str = recur_render(node.index_variable)
		local start_str = recur_render(node.start_expression)
		local end_str = recur_render(node.end_expression)
		return ("Sum[%s, {%s, %s, %s}]"):format(body_str, index_var_str, start_str, end_str)
	end,

	symbol = function(node, _)
		local constant_info = constants.get(node.name)
		if constant_info and constant_info.wolfram then
			return constant_info.wolfram
		end
		return node.name
	end,
}

return M
