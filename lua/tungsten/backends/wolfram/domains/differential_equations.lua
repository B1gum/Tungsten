-- lua/tungsten/domains/differential_equations/wolfram_handlers.lua

local config = require("tungsten.config")

local M = {}

local function default_independent_var(dependent_var_map)
	for _, v in pairs(dependent_var_map or {}) do
		return v
	end

	return "x"
end

local function map_function_name(func_name_str)
	local wolfram_opts = (config.backend_opts and config.backend_opts.wolfram) or {}
	local func_name_map = wolfram_opts.function_mappings or {}
	local wolfram_func_name = func_name_map[func_name_str:lower()]

	if not wolfram_func_name then
		wolfram_func_name = func_name_str:match("^%a") and (func_name_str:sub(1, 1):upper() .. func_name_str:sub(2))
			or func_name_str
	end

	return wolfram_func_name
end

local function find_ode_vars(equation_nodes)
	local dependent_vars = {}
	local independent_vars = {}
	local seen_dependent = {}
	local seen_independent = {}
	local dependent_var_map = {}

	local function visitor(node)
		if not node or type(node) ~= "table" then
			return
		end

		if node.type == "ordinary_derivative" then
			local func_name_str
			if node.expression.type == "function_call" then
				func_name_str = node.expression.name_node.name
			elseif node.expression.type == "variable" then
				func_name_str = node.expression.name
			end

			if func_name_str and not seen_dependent[func_name_str] then
				local indep_name = (node.variable and node.variable.name) or "x"
				local wolfram_func_name = map_function_name(func_name_str)

				table.insert(dependent_vars, wolfram_func_name .. "[" .. indep_name .. "]")
				seen_dependent[func_name_str] = true
				dependent_var_map[func_name_str] = indep_name

				if not seen_independent[indep_name] then
					table.insert(independent_vars, indep_name)
					seen_independent[indep_name] = true
				end
			end
		elseif node.type == "variable" and not seen_dependent[node.name] then
			if node.name ~= "x" and node.name ~= "t" then
				local indep_name = "x"
				local wolfram_func_name = map_function_name(node.name)

				table.insert(dependent_vars, wolfram_func_name .. "[" .. indep_name .. "]")
				seen_dependent[node.name] = true
				dependent_var_map[node.name] = indep_name
			end
		end

		for _, v in pairs(node) do
			if type(v) == "table" then
				visitor(v)
			end
		end
	end

	for _, eq_node in ipairs(equation_nodes) do
		visitor(eq_node)
	end

	if #independent_vars == 0 then
		table.insert(independent_vars, "x")
	end

	return table.concat(dependent_vars, ", "), table.concat(independent_vars, ", "), dependent_var_map
end

local function attach_independent_vars(node, dependent_var_map)
	if type(node) ~= "table" then
		return node
	end

	if node.type == "function_call" then
		local cloned = { type = "function_call" }

		if node.name_node then
			if node.name_node.type == "variable" and dependent_var_map[node.name_node.name] then
				cloned.name_node = { type = "variable", name = map_function_name(node.name_node.name) }
			else
				cloned.name_node = attach_independent_vars(node.name_node, dependent_var_map)
			end
		end

		if node.args then
			cloned.args = {}
			for i, arg in ipairs(node.args) do
				cloned.args[i] = attach_independent_vars(arg, dependent_var_map)
			end
		end

		return cloned
	end

	if node.type == "derivative" or node.type == "ordinary_derivative" then
		local cloned = {}
		for k, v in pairs(node) do
			if k == "variable" then
				cloned[k] = v
			elseif type(v) == "table" then
				cloned[k] = attach_independent_vars(v, dependent_var_map)
			else
				cloned[k] = v
			end
		end

		local function lookup_dependent_name(expr_node)
			if not expr_node or type(expr_node) ~= "table" then
				return nil
			end

			if expr_node.type == "function_call" and expr_node.name_node then
				return expr_node.name_node.name
			end

			if expr_node.type == "variable" then
				return expr_node.name
			end

			return nil
		end

		local dependent_name = lookup_dependent_name(cloned.expression) or (cloned.variable and cloned.variable.name)
		local indep_var = dependent_name and (dependent_var_map[dependent_name] or default_independent_var())

		if indep_var then
			if node.type == "derivative" and cloned.variable and cloned.variable.type == "variable" then
				if cloned.variable.name == dependent_name then
					cloned.variable = { type = "variable", name = map_function_name(dependent_name) }
				end
			elseif not cloned.variable or cloned.variable.type ~= "variable" then
				cloned.variable = { type = "variable", name = indep_var }
			end

			cloned.independent_variable = cloned.independent_variable or { type = "variable", name = indep_var }
		end

		return cloned
	end

	if node.type == "variable" and node.name and dependent_var_map[node.name] then
		return {
			type = "function_call",
			name_node = node,
			args = { { type = "variable", name = dependent_var_map[node.name] } },
		}
	end

	if #node > 0 then
		local cloned = {}
		for i, v in ipairs(node) do
			cloned[i] = attach_independent_vars(v, dependent_var_map)
		end
		return cloned
	end

	local cloned = {}
	for k, v in pairs(node) do
		if type(v) == "table" then
			cloned[k] = attach_independent_vars(v, dependent_var_map)
		else
			cloned[k] = v
		end
	end

	return cloned
end

local function extract_condition(condition)
	if not condition or type(condition) ~= "table" then
		return nil, nil
	end

	local lhs = condition.lhs or condition.left
	local rhs = condition.rhs or condition.right

	return lhs, rhs
end

local function render_conditions(conditions, walk, dependent_var_map)
	local rendered_conditions = {}

	for _, condition in ipairs(conditions or {}) do
		local lhs, rhs = extract_condition(condition)
		if lhs and rhs then
			local lhs_with_var = attach_independent_vars(lhs, dependent_var_map)
			local rhs_with_var = attach_independent_vars(rhs, dependent_var_map)
			table.insert(rendered_conditions, walk(lhs_with_var) .. " == " .. walk(rhs_with_var))
		end
	end

	return rendered_conditions
end

M.handlers = {
	["ordinary_derivative"] = function(node, walk)
		local order = (node.order and node.order.value) or 1
		local variable_str = (node.variable and walk(node.variable)) or "x"

		if node.expression.type == "function_call" then
			local raw_name = node.expression.name_node and node.expression.name_node.name
			local func_name = raw_name and map_function_name(raw_name) or walk(node.expression.name_node)
			local prime_str = string.rep("'", order)
			local arg_str = walk(node.expression.args[1])
			return func_name .. prime_str .. "[" .. arg_str .. "]"
		elseif node.expression.type == "variable" then
			local func_name = map_function_name(node.expression.name)
			local prime_str = string.rep("'", order)
			return func_name .. prime_str .. "[" .. variable_str .. "]"
		else
			local expression_str = walk(node.expression)
			if order == 1 then
				return "D[" .. expression_str .. ", " .. variable_str .. "]"
			else
				return "D[" .. expression_str .. ", {" .. variable_str .. ", " .. tostring(order) .. "}]"
			end
		end
	end,

	["ode"] = function(node, walk)
		local vars_str, indep_vars_str, dependent_var_map = find_ode_vars({ node })
		local lhs = attach_independent_vars(node.lhs, dependent_var_map)
		local rhs = attach_independent_vars(node.rhs, dependent_var_map)
		local equations = { walk(lhs) .. " == " .. walk(rhs) }

		local rendered_conditions = render_conditions(node.conditions, walk, dependent_var_map)
		for _, cond in ipairs(rendered_conditions) do
			table.insert(equations, cond)
		end

		local equations_str = (#equations > 1) and "{" .. table.concat(equations, ", ") .. "}" or equations[1]

		return "DSolve[" .. equations_str .. ", " .. vars_str .. ", " .. indep_vars_str .. "]"
	end,

	["ode_system"] = function(node, walk)
		local rendered_odes = {}
		local vars_str, indep_vars_str, dependent_var_map = find_ode_vars(node.equations)
		for _, ode_node in ipairs(node.equations) do
			local lhs = attach_independent_vars(ode_node.lhs, dependent_var_map)
			local rhs = attach_independent_vars(ode_node.rhs, dependent_var_map)
			table.insert(rendered_odes, walk(lhs) .. " == " .. walk(rhs))
		end

		local rendered_conditions = render_conditions(node.conditions, walk, dependent_var_map)
		for _, cond in ipairs(rendered_conditions) do
			table.insert(rendered_odes, cond)
		end

		local equations_str = "{" .. table.concat(rendered_odes, ", ") .. "}"
		return "DSolve[" .. equations_str .. ", {" .. vars_str .. "}, " .. indep_vars_str .. "]"
	end,

	["solve_system_equations_capture"] = function(node, walk)
		local rendered_equations = {}
		local vars_str, indep_vars_str, dependent_var_map = find_ode_vars(node.equations)
		for _, eq_node in ipairs(node.equations) do
			table.insert(rendered_equations, walk(attach_independent_vars(eq_node, dependent_var_map)))
		end
		local equations_str = "{" .. table.concat(rendered_equations, ", ") .. "}"

		if vars_str == "" then
			return "Solve[" .. equations_str .. "]"
		end

		return "DSolve[" .. equations_str .. ", {" .. vars_str .. "}, " .. indep_vars_str .. "]"
	end,

	["convolution"] = function(node, walk)
		return "Convolve[" .. walk(node.left) .. ", " .. walk(node.right) .. ", t, y]"
	end,

	["laplace_transform"] = function(node, walk)
		local func = walk(node.expression)
		func = func:gsub("u%((.-)%)", "HeavisideTheta(%1)")
		local from_var = "t"
		local to_var = "s"
		return "LaplaceTransform[" .. func .. ", " .. from_var .. ", " .. to_var .. "]"
	end,

	["inverse_laplace_transform"] = function(node, walk)
		local func = walk(node.expression)
		local from_var = "s"
		local to_var = "t"
		return "InverseLaplaceTransform[" .. func .. ", " .. from_var .. ", " .. to_var .. "]"
	end,

	["wronskian"] = function(node, walk)
		local var_str = (node.variable and walk(node.variable)) or "x"
		local function render_function(func_node)
			if type(func_node) == "table" then
				if func_node.type == "variable" or func_node.type == "subscript" then
					return walk(func_node) .. "[" .. var_str .. "]"
				end
			end
			return walk(func_node)
		end

		local rendered_functions = {}
		for _, func_node in ipairs(node.functions) do
			table.insert(rendered_functions, render_function(func_node))
		end
		local funcs_str = "{" .. table.concat(rendered_functions, ", ") .. "}"
		return "Wronskian[" .. funcs_str .. ", " .. var_str .. "]"
	end,
}

return M
