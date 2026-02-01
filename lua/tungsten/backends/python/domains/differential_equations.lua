-- lua/tungsten/backends/python/domains/differential_equations.lua
local M = {}

local function deepcopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepcopy(v)
	end
	return copy
end

local laplace_special_function_map = { u = "Heaviside", delta = "DiracDelta" }

local function rewrite_laplace_functions(expression)
	if type(expression) ~= "table" then
		return expression
	end
	local rewritten = deepcopy(expression)
	local function apply(node)
		if type(node) ~= "table" then
			return
		end

		if
			node.type == "function_call"
			and node.name_node
			and (node.name_node.type == "variable" or node.name_node.type == "greek")
		then
			local func_name = node.name_node.name
			if type(func_name) == "string" then
				local mapped = laplace_special_function_map[func_name:lower()]
				if mapped then
					node.name_node = deepcopy(node.name_node)
					node.name_node.name = mapped
					node.name_node.type = "variable"
				end
			end
		end
		for _, child in pairs(node) do
			apply(child)
		end
	end
	apply(rewritten)
	return rewritten
end

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

local function get_flat_name(node)
	if not node then
		return nil
	end
	if node.type == "variable" or node.type == "symbol" or node.type == "greek" then
		return node.name
	elseif node.type == "number" then
		return tostring(node.value)
	elseif node.type == "subscript" then
		local base = get_flat_name(node.base)
		local sub = get_flat_name(node.subscript)
		if base and sub then
			return base .. "_" .. sub
		end
	end
	return nil
end

M.handlers = {
	ode = function(node, walk)
		local equation_str = ("sp.Eq(%s, %s)"):format(walk(node.lhs), walk(node.rhs))
		local ics_str = render_ics(node.conditions, walk)
		local func_str = "y"
		local function find_func(n)
			if type(n) ~= "table" then
				return
			end
			if n.type == "ordinary_derivative" then
				func_str = walk(n.expression)
				return true
			end
			for _, child in pairs(n) do
				if find_func(child) then
					return true
				end
			end
		end
		find_func(node.lhs)

		if ics_str then
			return ("sp.dsolve(%s, %s, ics=%s)"):format(equation_str, func_str, ics_str)
		end
		return ("sp.dsolve(%s, %s)"):format(equation_str, func_str)
	end,

	ode_system = function(node, walk)
		local rendered_odes = {}
		local funcs_found = {}
		local indep_vars_found = {}
		local func_dependencies = {}

		local function add_dependency(func, var)
			if not func_dependencies[func] then
				func_dependencies[func] = {}
			end
			func_dependencies[func][var] = true
		end

		local function collect_info(n)
			if type(n) ~= "table" then
				return
			end

			if n.type == "ordinary_derivative" or n.type == "partial_derivative" then
				local func_name = walk(n.expression)
				funcs_found[func_name] = true

				if n.expression.type == "function_call" and n.expression.args then
					for _, arg in ipairs(n.expression.args) do
						local var_name = walk(arg)
						indep_vars_found[var_name] = true
						add_dependency(func_name, var_name)
					end
				end

				if n.type == "ordinary_derivative" and n.variable then
					local var_name = walk(n.variable)
					indep_vars_found[var_name] = true
					add_dependency(func_name, var_name)
				elseif n.type == "partial_derivative" and n.variables then
					for _, vinfo in ipairs(n.variables) do
						local var_name = walk(vinfo.variable)
						indep_vars_found[var_name] = true
						add_dependency(func_name, var_name)
					end
				end
			end

			for _, child in pairs(n) do
				collect_info(child)
			end
		end

		for _, ode_node in ipairs(node.equations) do
			table.insert(rendered_odes, ("sp.Eq(%s, %s)"):format(walk(ode_node.lhs), walk(ode_node.rhs)))
			collect_info(ode_node)
		end

		local is_pde = false
		for _, deps in pairs(func_dependencies) do
			local count = 0
			for _ in pairs(deps) do
				count = count + 1
			end
			if count > 1 then
				is_pde = true
				break
			end
		end

		local global_indep_count = 0
		for _ in pairs(indep_vars_found) do
			global_indep_count = global_indep_count + 1
		end

		local funcs_list = {}
		for f, _ in pairs(funcs_found) do
			table.insert(funcs_list, f)
		end
		table.sort(funcs_list)

		if is_pde then
			if #rendered_odes > 1 then
				local eq_list_str = "[" .. table.concat(rendered_odes, ", ") .. "]"
				return ("[sp.pdsolve(eq) for eq in %s]"):format(eq_list_str)
			else
				local func_arg_single = funcs_list[1] or "f"
				local equation = rendered_odes[1]
				return ("sp.pdsolve(%s, %s)"):format(equation, func_arg_single)
			end
		end

		if global_indep_count > 1 then
			local ics_str = render_ics(node.conditions, walk)
			local eq_list_str = "[" .. table.concat(rendered_odes, ", ") .. "]"

			if ics_str then
				return ("[sp.dsolve(eq, ics=%s) for eq in %s]"):format(ics_str, eq_list_str)
			else
				return ("[sp.dsolve(eq) for eq in %s]"):format(eq_list_str)
			end
		end

		local funcs_arg = "[" .. table.concat(funcs_list, ", ") .. "]"
		local ics_str = render_ics(node.conditions, walk)

		if ics_str then
			local equations_arg = "[" .. table.concat(rendered_odes, ", ") .. "]"
			return ("sp.dsolve(%s, %s, ics=%s)"):format(equations_arg, funcs_arg, ics_str)
		else
			local conditions = render_conditions(node.conditions, walk)
			for _, condition_str in ipairs(conditions) do
				table.insert(rendered_odes, condition_str)
			end
			local equations_arg = "[" .. table.concat(rendered_odes, ", ") .. "]"
			return ("sp.dsolve(%s, %s)"):format(equations_arg, funcs_arg)
		end
	end,

	wronskian = function(node, walk)
		local rendered_functions = {}
		for _, func_node in ipairs(node.functions) do
			local flat = get_flat_name(func_node)
			if flat then
				table.insert(rendered_functions, flat)
			else
				table.insert(rendered_functions, walk(func_node))
			end
		end
		local funcs_str = "[" .. table.concat(rendered_functions, ", ") .. "]"

		local var_flat = get_flat_name(node.variable)
		local var_str = var_flat or (node.variable and walk(node.variable)) or "x"

		return ("sp.wronskian(%s, %s)"):format(funcs_str, var_str)
	end,

	laplace_transform = function(node, walk)
		local func = walk(rewrite_laplace_functions(node.expression))
		return ("sp.laplace_transform(%s, t, s, noconds=True)"):format(func)
	end,

	inverse_laplace_transform = function(node, walk)
		local func = walk(rewrite_laplace_functions(node.expression))
		return ("sp.inverse_laplace_transform(%s, s, t)"):format(func)
	end,

	convolution = function(node, walk)
		local f = walk(node.left)
		local g = walk(node.right)

		local t_var = (node.variable and get_flat_name(node.variable)) or "t"
		local y_var = (node.integration_variable and get_flat_name(node.integration_variable)) or "y"

		return ("sp.integrate(sp.sympify(%s).subs(%s, %s) * sp.sympify(%s).subs(%s, %s - %s), (%s, 0, %s))"):format(
			f,
			t_var,
			y_var,
			g,
			t_var,
			t_var,
			y_var,
			y_var,
			t_var
		)
	end,
}

return M
