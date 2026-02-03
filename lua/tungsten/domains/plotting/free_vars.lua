local M = {}
local constants = require("tungsten.core.constants")

local function collect(node, bound, acc)
	if type(node) ~= "table" then
		return
	end

	bound = bound or {}

	local t = node.type
	if t == "constant" then
		return
	end

	if t == "variable" or t == "symbol" or t == "greek" then
		local name = node.name
		if constants.is_constant(name) then
			return
		end
		if name and not bound[name] then
			acc[name] = true
		end
		return
	end

	if t == "indefinite_integral" or t == "definite_integral" then
		local new_bound = bound
		if node.variable and node.variable.name then
			new_bound = {}
			for k, v in pairs(bound) do
				new_bound[k] = v
			end
			new_bound[node.variable.name] = true
		end
		if node.integrand then
			collect(node.integrand, new_bound, acc)
		end
		if t == "definite_integral" then
			collect(node.lower_bound, bound, acc)
			collect(node.upper_bound, bound, acc)
		end
		return
	end

	if t == "summation" or t == "product" then
		if node.start_expression then
			collect(node.start_expression, bound, acc)
		end
		if node.end_expression then
			collect(node.end_expression, bound, acc)
		end
		local new_bound = bound
		if node.index_variable and node.index_variable.name then
			new_bound = {}
			for k, v in pairs(bound) do
				new_bound[k] = v
			end
			new_bound[node.index_variable.name] = true
		end
		if node.body_expression then
			collect(node.body_expression, new_bound, acc)
		end
		return
	end

	if t == "limit" then
		if node.point then
			collect(node.point, bound, acc)
		end
		local new_bound = bound
		if node.variable and node.variable.name then
			new_bound = {}
			for k, v in pairs(bound) do
				new_bound[k] = v
			end
			new_bound[node.variable.name] = true
		end
		if node.expression then
			collect(node.expression, new_bound, acc)
		end
		return
	end

	if t == "ordinary_derivative" then
		if node.expression then
			collect(node.expression, bound, acc)
		end
		if node.variable and node.variable.name and not bound[node.variable.name] then
			acc[node.variable.name] = true
		end
		if node.order then
			collect(node.order, bound, acc)
		end
		return
	end

	if t == "partial_derivative" then
		if node.expression then
			collect(node.expression, bound, acc)
		end
		for _, var in ipairs(node.variables or {}) do
			if var.name and not bound[var.name] then
				acc[var.name] = true
			end
		end
		if node.overall_order then
			collect(node.overall_order, bound, acc)
		end
		return
	end

	if t == "function_call" then
		for _, arg in ipairs(node.args or {}) do
			collect(arg, bound, acc)
		end
		return
	end

	for k, v in pairs(node) do
		if k ~= "type" and type(v) == "table" then
			if v.type then
				collect(v, bound, acc)
			else
				for _, child in pairs(v) do
					collect(child, bound, acc)
				end
			end
		end
	end
end

function M.find(node)
	local names = {}
	collect(node, {}, names)
	local result = {}
	for name in pairs(names) do
		table.insert(result, name)
	end
	table.sort(result)
	return result
end

return M
