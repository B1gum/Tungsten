-- lua/tungsten/backends/python/domains/calculus.lua
-- SymPy handlers for calculus operations

local M = {}

M.handlers = {
	ordinary_derivative = function(node, walk)
		local order = (node.order and walk(node.order)) or 1
		local expression_str = walk(node.expression)
		local variable_str = walk(node.variable)

		if tostring(order) == "1" then
			return "sp.diff(" .. expression_str .. ", " .. variable_str .. ")"
		else
			return "sp.diff(" .. expression_str .. ", " .. variable_str .. ", " .. tostring(order) .. ")"
		end
	end,

	partial_derivative = function(node, recur_render)
		local expr_str = recur_render(node.expression)
		local parts = {}
		for _, var_node_info in ipairs(node.variables) do
			local var_name_str = recur_render(var_node_info.variable)
			local var_order_str = recur_render(var_node_info.order)
			table.insert(parts, var_name_str)
			if var_order_str ~= "1" then
				table.insert(parts, var_order_str)
			end
		end
		return "sp.diff(" .. expr_str .. ", " .. table.concat(parts, ", ") .. ")"
	end,

	limit = function(node, recur_render)
		local expr_str = recur_render(node.expression)
		local var_str = recur_render(node.variable)
		local point_str = recur_render(node.point)
		return ("sp.limit(%s, %s, %s)"):format(expr_str, var_str, point_str)
	end,

	indefinite_integral = function(node, recur_render)
		local integrand_str = recur_render(node.integrand)
		local var_str = recur_render(node.variable)
		return ("sp.integrate(%s, %s)"):format(integrand_str, var_str)
	end,

	definite_integral = function(node, recur_render)
		local integrand_str = recur_render(node.integrand)
		local var_str = recur_render(node.variable)
		local lower_bound_str = recur_render(node.lower_bound)
		local upper_bound_str = recur_render(node.upper_bound)
		return ("sp.integrate(%s, (%s, %s, %s))"):format(integrand_str, var_str, lower_bound_str, upper_bound_str)
	end,

	summation = function(node, recur_render)
		local body_str = recur_render(node.body_expression)
		local index_var_str = recur_render(node.index_variable)
		local start_str = recur_render(node.start_expression)
		local end_str = recur_render(node.end_expression)
		return ("sp.summation(%s, (%s, %s, %s))"):format(body_str, index_var_str, start_str, end_str)
	end,

	symbol = function(node, _)
		if node.name == "infinity" then
			return "sp.oo"
		elseif node.name == "pi" then
			return "sp.pi"
		else
			return node.name
		end
	end,
}

return M
