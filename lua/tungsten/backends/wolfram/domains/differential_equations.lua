-- lua/tungsten/domains/differential_equations/wolfram_handlers.lua

local config = require("tungsten.config")

local M = {}

local function default_independent_var(dependent_var_map, dependent_name)
	if dependent_name then
		local vars_for_dep = dependent_var_map and dependent_var_map[dependent_name]
		if vars_for_dep and vars_for_dep[1] then
			return vars_for_dep[1]
		end
	end
	for _, v in pairs(dependent_var_map or {}) do
		if type(v) == "table" and v[1] then
			return v[1]
		end
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
	local seen_independent = {}
	local dependent_var_map = {}
	local dependent_seen_order = {}
	local dependent_indep_seen = {}

	local function add_dependent_var(func_name, indep_names)
		if not func_name then
			return
		end

		-- Ensure input is a table (list of variables)
		local indeps_to_add = type(indep_names) == "table" and indep_names or { indep_names }

		if not dependent_var_map[func_name] then
			dependent_var_map[func_name] = {}
			dependent_seen_order[#dependent_seen_order + 1] = func_name
			dependent_indep_seen[func_name] = {}
		end

		for _, indep_name in ipairs(indeps_to_add) do
			if indep_name and not dependent_indep_seen[func_name][indep_name] then
				dependent_indep_seen[func_name][indep_name] = true
				table.insert(dependent_var_map[func_name], indep_name)
			end

			if indep_name and not seen_independent[indep_name] then
				seen_independent[indep_name] = true
				table.insert(independent_vars, indep_name)
			end
		end
	end

	-- Pass 1: Scan ONLY for derivatives to establish the "ground truth" of independent variables
	local function derivative_visitor(node)
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
			local indep_name = (node.variable and node.variable.name) or "x"
			add_dependent_var(func_name_str, indep_name)
		elseif node.type == "derivative" then
			local func_name_str = node.variable and node.variable.name
			local indep_name = (node.independent_variable and node.independent_variable.name)
			add_dependent_var(func_name_str, indep_name or "x")
		elseif node.type == "partial_derivative" then
			local func_name_str
			if node.expression and node.expression.type == "function_call" then
				func_name_str = node.expression.name_node and node.expression.name_node.name
			elseif node.expression and node.expression.type == "variable" then
				func_name_str = node.expression.name
			end
			for _, var_info in ipairs(node.variables or {}) do
				local indep_name = (var_info.variable and var_info.variable.name) or "x"
				add_dependent_var(func_name_str, indep_name)
			end
		end

		for _, v in pairs(node) do
			if type(v) == "table" then
				derivative_visitor(v)
			end
		end
	end

	-- Pass 2: Infer dependencies for bare variables using ALL found independent variables
	local function variable_visitor(node)
		if not node or type(node) ~= "table" then
			return
		end

		if node.type == "variable" then
			-- Check if this variable is one of the independent variables (like x, y, t)
			local is_independent = false
			for _, iv in ipairs(independent_vars) do
				if node.name == iv then
					is_independent = true
					break
				end
			end

			if not is_independent then
				-- If it's a dependent variable (like u, v), assign ALL found independent vars to it
				-- If no independent vars found yet, default to "x"
				local target_indeps = #independent_vars > 0 and independent_vars or { "x" }
				add_dependent_var(node.name, target_indeps)
			end
		end

		for _, v in pairs(node) do
			if type(v) == "table" then
				variable_visitor(v)
			end
		end
	end

	-- Execute Scan
	for _, eq_node in ipairs(equation_nodes) do
		derivative_visitor(eq_node)
	end
	for _, eq_node in ipairs(equation_nodes) do
		variable_visitor(eq_node)
	end

	if #independent_vars == 0 then
		table.insert(independent_vars, "x")
	end

	-- Construct the string for DSolve arguments
	for _, func_name in ipairs(dependent_seen_order) do
		local wolfram_func_name = map_function_name(func_name)
		local indep_list = dependent_var_map[func_name]

		-- Sort independent variables to ensure consistent order (e.g. u[x,y] everywhere)
		table.sort(indep_list, function(a, b)
			local ia, ib = 0, 0
			for k, v in ipairs(independent_vars) do
				if v == a then
					ia = k
				end
				if v == b then
					ib = k
				end
			end
			return ia < ib
		end)

		local indep_str = indep_list and (table.concat(indep_list, ", ") or "") or ""
		table.insert(dependent_vars, wolfram_func_name .. "[" .. indep_str .. "]")
	end

	local indep_vars_str = "{" .. table.concat(independent_vars, ", ") .. "}"

	return table.concat(dependent_vars, ", "), indep_vars_str, dependent_var_map
end

local current_dependent_var_map = nil

local function get_independent_vars_for(func_name, fallback_variable)
	if func_name and current_dependent_var_map and current_dependent_var_map[func_name] then
		return current_dependent_var_map[func_name]
	end

	local default_var = fallback_variable or default_independent_var(current_dependent_var_map, func_name)
	return { default_var }
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
		elseif node.name_node and node.name_node.type == "variable" and dependent_var_map[node.name_node.name] then
			cloned.args = {}
			for i, indep_var in ipairs(dependent_var_map[node.name_node.name]) do
				cloned.args[i] = { type = "variable", name = indep_var }
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
		local indep_var_list = dependent_name and dependent_var_map[dependent_name]
		local indep_var = (indep_var_list and indep_var_list[1])
			or default_independent_var(dependent_var_map, dependent_name)

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
			args = (function()
				local args = {}
				for i, indep_var in ipairs(dependent_var_map[node.name]) do
					args[i] = { type = "variable", name = indep_var }
				end
				return args
			end)(),
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
	["partial_derivative"] = function(node, walk)
		local fallback_var = (
			node.variables
			and node.variables[1]
			and node.variables[1].variable
			and node.variables[1].variable.name
		)
		local target_expr
		local func_name

		if node.expression.type == "function_call" then
			func_name = node.expression.name_node and node.expression.name_node.name
		elseif node.expression.type == "variable" then
			func_name = node.expression.name
		end

		if func_name then
			local indep_vars = get_independent_vars_for(func_name, fallback_var)
			target_expr = map_function_name(func_name) .. "[" .. table.concat(indep_vars, ", ") .. "]"
		else
			target_expr = walk(node.expression)
		end

		local derivative_vars = {}
		for _, var_info in ipairs(node.variables or {}) do
			local var_str = walk(var_info.variable)
			local order_str = var_info.order and walk(var_info.order) or "1"
			if tostring(order_str) == "1" then
				table.insert(derivative_vars, var_str)
			else
				table.insert(derivative_vars, "{" .. var_str .. ", " .. tostring(order_str) .. "}")
			end
		end

		return "D[" .. target_expr .. ", " .. table.concat(derivative_vars, ", ") .. "]"
	end,

	["ordinary_derivative"] = function(node, walk)
		local order = (node.order and node.order.value) or 1
		local variable_str = (node.variable and walk(node.variable)) or "x"

		if node.expression.type == "function_call" then
			local raw_name = node.expression.name_node and node.expression.name_node.name
			local func_name = raw_name and map_function_name(raw_name) or walk(node.expression.name_node)
			local indep_vars = get_independent_vars_for(raw_name, variable_str)
			local arg_str = table.concat(indep_vars, ", ")
			local target = func_name .. "[" .. arg_str .. "]"
			if order == 1 then
				return "D[" .. target .. ", " .. variable_str .. "]"
			end
			return "D[" .. target .. ", {" .. variable_str .. ", " .. tostring(order) .. "}]"
		elseif node.expression.type == "variable" then
			local func_name = map_function_name(node.expression.name)
			local indep_vars = get_independent_vars_for(node.expression.name, variable_str)
			local arg_str = table.concat(indep_vars, ", ")
			local target = func_name .. "[" .. arg_str .. "]"
			if order == 1 then
				return "D[" .. target .. ", " .. variable_str .. "]"
			end
			return "D[" .. target .. ", {" .. variable_str .. ", " .. tostring(order) .. "}]"
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
		local prev_map = current_dependent_var_map
		current_dependent_var_map = dependent_var_map
		local lhs = attach_independent_vars(node.lhs, dependent_var_map)
		local rhs = attach_independent_vars(node.rhs, dependent_var_map)
		local equations = { walk(lhs) .. " == " .. walk(rhs) }

		local rendered_conditions = render_conditions(node.conditions, walk, dependent_var_map)
		for _, cond in ipairs(rendered_conditions) do
			table.insert(equations, cond)
		end

		local equations_str = (#equations > 1) and "{" .. table.concat(equations, ", ") .. "}" or equations[1]

		local result = "DSolve[" .. equations_str .. ", " .. vars_str .. ", " .. indep_vars_str .. "]"
		current_dependent_var_map = prev_map
		return result
	end,

	["ode_system"] = function(node, walk)
		local rendered_odes = {}
		local vars_str, indep_vars_str, dependent_var_map = find_ode_vars(node.equations)
		local prev_map = current_dependent_var_map
		current_dependent_var_map = dependent_var_map
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
		local result = "DSolve[" .. equations_str .. ", {" .. vars_str .. "}, " .. indep_vars_str .. "]"
		current_dependent_var_map = prev_map
		return result
	end,

	["solve_system_equations_capture"] = function(node, walk)
		local rendered_equations = {}
		local vars_str, indep_vars_str, dependent_var_map = find_ode_vars(node.equations)
		local prev_map = current_dependent_var_map
		current_dependent_var_map = dependent_var_map
		for _, eq_node in ipairs(node.equations) do
			table.insert(rendered_equations, walk(attach_independent_vars(eq_node, dependent_var_map)))
		end
		local equations_str = "{" .. table.concat(rendered_equations, ", ") .. "}"

		if vars_str == "" then
			current_dependent_var_map = prev_map
			return "Solve[" .. equations_str .. "]"
		end

		local result = "DSolve[" .. equations_str .. ", {" .. vars_str .. "}, " .. indep_vars_str .. "]"
		current_dependent_var_map = prev_map
		return result
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
