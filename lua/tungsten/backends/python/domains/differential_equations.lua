-- lua/tungsten/backends/python/domains/differential_equations.lua
-- SymPy handlers for differential equation operations

local M = {}

M.handlers = {
	ode = function(node, walk)
		local equation_str = ("sp.Eq(%s, %s)"):format(walk(node.lhs), walk(node.rhs))
		return "sp.dsolve(" .. equation_str .. ")"
	end,

	ode_system = function(node, walk)
		local rendered_odes = {}
		for _, ode_node in ipairs(node.equations) do
			table.insert(rendered_odes, ("sp.Eq(%s, %s)"):format(walk(ode_node.lhs), walk(ode_node.rhs)))
		end
		return "sp.dsolve([" .. table.concat(rendered_odes, ", ") .. "])"
	end,

	wronskian = function(node, walk)
		local rendered_functions = {}
		for _, func_node in ipairs(node.functions) do
			table.insert(rendered_functions, walk(func_node))
		end
		local funcs_str = "[" .. table.concat(rendered_functions, ", ") .. "]"
		local var_str = (node.variable and walk(node.variable)) or "x"
		return ("sp.wronskian(%s, %s)"):format(funcs_str, var_str)
	end,

	laplace_transform = function(node, walk)
		local func = walk(node.expression)
		local from_var = "t"
		local to_var = "s"
		return ("sp.laplace_transform(%s, %s, %s)"):format(func, from_var, to_var)
	end,

	inverse_laplace_transform = function(node, walk)
		local func = walk(node.expression)
		local from_var = "s"
		local to_var = "t"
		return ("sp.inverse_laplace_transform(%s, %s, %s)"):format(func, from_var, to_var)
	end,

	convolution = function(node, walk)
		return ("sp.convolution(%s, %s, t, y)"):format(walk(node.left), walk(node.right))
	end,
}

return M
