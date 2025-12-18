-- lua/tungsten/backends/python/domains/differential_equations.lua
-- SymPy handlers for differential equation operations

local M = {}

local function extract_condition(condition)
	if not condition or type(condition) ~= "table" then
		return nil, nil
	end

	local lhs = condition.lhs or condition.left
	local rhs = condition.rhs or condition.right

	return lhs, rhs
end

local function render_conditions(conditions, walk)
	local rendered = {}

	for _, condition in ipairs(conditions or {}) do
		local lhs, rhs = extract_condition(condition)
		if lhs and rhs then
			table.insert(rendered, ("sp.Eq(%s, %s)"):format(walk(lhs), walk(rhs)))
		end
	end

	return rendered
end

local function render_ics(conditions, walk)
	local entries = {}

	for _, condition in ipairs(conditions or {}) do
		local lhs, rhs = extract_condition(condition)
		if lhs and rhs then
			table.insert(entries, string.format("%s: %s", walk(lhs), walk(rhs)))
		end
	end

	if #entries == 0 then
		return nil
	end

	return "{" .. table.concat(entries, ", ") .. "}"
end

M.handlers = {
	ode = function(node, walk)
		local equation_str = ("sp.Eq(%s, %s)"):format(walk(node.lhs), walk(node.rhs))
		local ics_str = render_ics(node.conditions, walk)

		if ics_str then
			return ("sp.dsolve(%s, ics=%s)"):format(equation_str, ics_str)
		end

		return "sp.dsolve(" .. equation_str .. ")"
	end,

	ode_system = function(node, walk)
		local rendered_odes = {}
		local conditions = render_conditions(node.conditions, walk)
		for _, ode_node in ipairs(node.equations) do
			table.insert(rendered_odes, ("sp.Eq(%s, %s)"):format(walk(ode_node.lhs), walk(ode_node.rhs)))
		end

		for _, condition_str in ipairs(conditions) do
			table.insert(rendered_odes, condition_str)
		end

		local ics_str = render_ics(node.conditions, walk)
		local equations_arg = "[" .. table.concat(rendered_odes, ", ") .. "]"

		if ics_str then
			return ("sp.dsolve(%s, ics=%s)"):format(equations_arg, ics_str)
		end

		return "sp.dsolve(" .. equations_arg .. ")"
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
