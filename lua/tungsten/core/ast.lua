-- core/ast.lua
-- Utility functions for creating and manipulating Abstract Syntax Tree (AST) nodes.
-- Each function creates a table representing a specific node type in the AST.
------------------------------------------------------------------------------------

local M = {}

local function node(t, fields)
	fields.type = t
	return fields
end

function M.create_number_node(value)
	return node("number", { value = value })
end

function M.create_quantity_node(value, unit_expression)
	return node("quantity", { value = value, unit = unit_expression })
end

function M.create_angle_node(value)
	return node("angle", { value = value })
end

function M.create_num_node(value)
	return node("num_cmd", { value = value })
end

function M.create_unit_component_node(name)
	return node("unit_component", { name = name })
end

function M.create_variable_node(name)
	return node("variable", { name = name })
end

function M.create_constant_node(name)
	return node("constant", { name = name })
end

function M.create_greek_node(name)
	return node("greek", { name = name })
end

function M.create_solve_system_equations_capture_node(equations)
	return node("solve_system_equations_capture", { equations = equations })
end

function M.create_binary_operation_node(op, left, right)
	if op == "\\cdot" then
		op = "*"
	end
	return node("binary", { operator = op, left = left, right = right })
end

function M.create_unary_operation_node(operator, value)
	return node("unary", { operator = operator, value = value })
end

function M.create_factorial_node(expression)
	return node("factorial", { expression = expression })
end

function M.create_function_call_node(name_node, args_table)
	return node("function_call", { name_node = name_node, args = args_table })
end

function M.create_abs_node(expression)
	return M.create_function_call_node(M.create_variable_node("abs"), { expression })
end

function M.create_symbol_node(name)
	return node("symbol", { name = name })
end

function M.create_fraction_node(numerator, denominator)
	return node("fraction", { numerator = numerator, denominator = denominator })
end

function M.create_binomial_node(n, k)
	return node("binomial", { n = n, k = k })
end

function M.create_sqrt_node(radicand, index)
	local t = { type = "sqrt", radicand = radicand }
	if index then
		t.index = index
	end
	return t
end

function M.create_superscript_node(base, exponent)
	return node("superscript", { base = base, exponent = exponent })
end

function M.create_subscript_node(base, sub)
	return node("subscript", { base = base, subscript = sub })
end

function M.create_limit_node(variable, point, expression)
	return node("limit", { variable = variable, point = point, expression = expression })
end

function M.create_indefinite_integral_node(integrand, variable)
	return node("indefinite_integral", { integrand = integrand, variable = variable })
end

function M.create_definite_integral_node(integrand, variable, lower_bound, upper_bound)
	return node("definite_integral", {
		integrand = integrand,
		variable = variable,
		lower_bound = lower_bound,
		upper_bound = upper_bound,
	})
end

function M.create_ordinary_derivative_node(expression, variable, order)
	return node("ordinary_derivative", {
		expression = expression,
		variable = variable,
		order = order or { type = "number", value = 1 },
	})
end

function M.create_differentiation_term_node(variable_node, order_node)
	return node("differentiation_term", {
		variable = variable_node,
		order = order_node or { type = "number", value = 1 },
	})
end

function M.create_partial_derivative_node(expression, overall_order, variables_list)
	return node("partial_derivative", {
		expression = expression,
		overall_order = overall_order or { type = "number", value = #variables_list },
		variables = variables_list,
	})
end

function M.create_summation_node(index_variable, start_expression, end_expression, body_expression)
	return node("summation", {
		index_variable = index_variable,
		start_expression = start_expression,
		end_expression = end_expression,
		body_expression = body_expression,
	})
end

function M.create_product_node(index_variable, start_expression, end_expression, body_expression)
	return node("product", {
		index_variable = index_variable,
		start_expression = start_expression,
		end_expression = end_expression,
		body_expression = body_expression,
	})
end

function M.create_matrix_node(rows, env_type)
	return node("matrix", { rows = rows, env_type = env_type })
end

function M.create_vector_node(elements, orientation)
	return node("vector", { elements = elements, orientation = orientation or "column" })
end

function M.create_symbolic_vector_node(name_expression, command)
	return node("symbolic_vector", { name_expr = name_expression, command = command })
end

function M.create_vector_list_node(vectors)
	return node("vector_list", { vectors = vectors })
end

function M.create_determinant_node(expression)
	return node("determinant", { expression = expression })
end

function M.create_transpose_node(expression)
	return node("transpose", { expression = expression })
end

function M.create_inverse_node(expression)
	return node("inverse", { expression = expression })
end

function M.create_dot_product_node(left_vector, right_vector)
	return node("dot_product", { left = left_vector, right = right_vector })
end

function M.create_cross_product_node(left_vector, right_vector)
	return node("cross_product", { left = left_vector, right = right_vector })
end

function M.create_norm_node(expression, p_value)
	return node("norm", { expression = expression, p = p_value })
end

function M.create_gauss_eliminate_node(matrix_expression_ast)
	return node("gauss_eliminate", { expression = matrix_expression_ast })
end

function M.create_linear_independent_test_node(target_ast)
	return node("linear_independent_test", { target = target_ast })
end

function M.create_rank_node(matrix_expression_ast)
	return node("rank", { expression = matrix_expression_ast })
end

function M.create_eigenvalues_node(matrix_expression_ast)
	return node("eigenvalues", { expression = matrix_expression_ast })
end

function M.create_eigenvectors_node(matrix_expression_ast)
	return node("eigenvectors", { expression = matrix_expression_ast })
end

function M.create_eigensystem_node(matrix_expression_ast)
	return node("eigensystem", { expression = matrix_expression_ast })
end

function M.create_solve_system_node(equations_list, variables_list)
	return node("solve_system", { equations = equations_list, variables = variables_list })
end

function M.create_ode_node(lhs, rhs, conditions)
	local ode_node = node("ode", { lhs = lhs, rhs = rhs })
	if conditions and #conditions > 0 then
		ode_node.conditions = conditions
	end
	return ode_node
end

function M.create_ode_system_node(equations, conditions)
	local ode_system = node("ode_system", { equations = equations })
	if conditions and #conditions > 0 then
		ode_system.conditions = conditions
	end
	return ode_system
end

function M.create_wronskian_node(functions_list)
	return node("wronskian", { functions = functions_list })
end

function M.create_laplace_transform_node(expression)
	return node("laplace_transform", { expression = expression })
end

function M.create_inverse_laplace_transform_node(expression)
	return node("inverse_laplace_transform", { expression = expression })
end

function M.create_convolution_node(left, right)
	return node("convolution", { left = left, right = right })
end

function M.create_sequence_node(nodes)
	return node("Sequence", { nodes = nodes })
end

function M.create_point2_node(x, y)
	return node("Point2", { x = x, y = y })
end

function M.create_point3_node(x, y, z)
	return node("Point3", { x = x, y = y, z = z })
end

function M.create_equality_node(lhs, rhs)
	return node("Equality", { lhs = lhs, rhs = rhs })
end

function M.create_inequality_node(lhs, op, rhs)
	return node("Inequality", { lhs = lhs, op = op, rhs = rhs })
end

function M.create_parametric2d_node(x, y)
	return node("Parametric2D", { x = x, y = y })
end

function M.create_parametric3d_node(x, y, z)
	return node("Parametric3D", { x = x, y = y, z = z })
end

function M.create_polar2d_node(r)
	return node("Polar2D", { r = r })
end

function M.is_sequence_node(n)
	return type(n) == "table" and n.type == "Sequence"
end

function M.is_point2_node(n)
	return type(n) == "table" and n.type == "Point2"
end

function M.is_point3_node(n)
	return type(n) == "table" and n.type == "Point3"
end

function M.is_equality_node(n)
	if type(n) ~= "table" then
		return false
	end

	return n.type == "Equality" or n.type == "equality"
end

function M.unwrap_equality_rhs(ast)
	if M.is_equality_node(ast) and ast.rhs then
		return ast.rhs
	end

	return ast
end

function M.is_inequality_node(n)
	return type(n) == "table" and n.type == "Inequality"
end

function M.is_parametric2d_node(n)
	return type(n) == "table" and n.type == "Parametric2D"
end

function M.is_parametric3d_node(n)
	return type(n) == "table" and n.type == "Parametric3D"
end

function M.is_polar2d_node(n)
	return type(n) == "table" and n.type == "Polar2D"
end

local function canonical(n)
	if type(n) ~= "table" then
		return tostring(n)
	end

	local tag = n.type
	if tag == "number" then
		return tostring(n.value)
	elseif tag == "variable" or tag == "symbol" or tag == "greek" then
		return tostring(n.name)
	elseif tag == "Sequence" then
		local parts = {}
		for _, child in ipairs(n.nodes) do
			parts[#parts + 1] = canonical(child)
		end
		return "Sequence(" .. table.concat(parts, ",") .. ")"
	elseif tag == "Point2" then
		return "Point2(" .. canonical(n.x) .. "," .. canonical(n.y) .. ")"
	elseif tag == "Point3" then
		return "Point3(" .. canonical(n.x) .. "," .. canonical(n.y) .. "," .. canonical(n.z) .. ")"
	elseif tag == "Equality" then
		return "Equality(" .. canonical(n.lhs) .. "," .. canonical(n.rhs) .. ")"
	elseif tag == "Inequality" then
		return "Inequality(" .. canonical(n.lhs) .. "," .. tostring(n.op) .. "," .. canonical(n.rhs) .. ")"
	elseif tag == "Parametric2D" then
		return "Parametric2D(" .. canonical(n.x) .. "," .. canonical(n.y) .. ")"
	elseif tag == "Parametric3D" then
		return "Parametric3D(" .. canonical(n.x) .. "," .. canonical(n.y) .. "," .. canonical(n.z) .. ")"
	elseif tag == "Polar2D" then
		return "Polar2D(" .. canonical(n.r) .. ")"
	elseif tag == "function_call" then
		local name = canonical(n.name_node)
		local args_parts = {}
		if n.args then
			for _, arg in ipairs(n.args) do
				args_parts[#args_parts + 1] = canonical(arg)
			end
		end
		return name .. "(" .. table.concat(args_parts, ",") .. ")"
	else
		local keys = {}
		for k, _ in pairs(n) do
			if k ~= "type" then
				keys[#keys + 1] = k
			end
		end
		table.sort(keys)
		local parts = {}
		for _, k in ipairs(keys) do
			parts[#parts + 1] = k .. "=" .. canonical(n[k])
		end
		return tostring(tag) .. "{" .. table.concat(parts, ",") .. "}"
	end
end

M.canonical = canonical

return M
