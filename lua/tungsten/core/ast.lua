-- core/ast.lua
-- Utility functions for creating and manipulating Abstract Syntax Tree (AST) nodes.
-- Each function creates a table representing a specific node type in the AST.
------------------------------------------------------------------------------------

local M = {}

local function node(t, fields)
  fields.type = t
  return fields
end

function M.create_binary_operation_node(op, left, right)
  if op == "\\cdot" then op = "*" end
  return node("binary", { operator = op, left = left, right = right })
end

function M.create_unary_operation_node(operator, value)
  return node("unary", { operator = operator, value = value })
end

function M.create_function_call_node(name_node, args_table)
  return node("function_call", { name_node = name_node, args = args_table })
end

function M.create_symbol_node(name)
  return node("symbol", { name = name })
end

function M.create_fraction_node(numerator, denominator)
  return node("fraction", { numerator = numerator, denominator = denominator })
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

function M.create_matrix_node(rows, env_type)
  return node("matrix", { rows = rows, env_type = env_type })
end

function M.create_vector_node(elements, orientation)
  return node("vector", { elements = elements, orientation = orientation or "column" })
end

function M.create_symbolic_vector_node(name_expression, command)
  return node("symbolic_vector", { name_expr = name_expression, command = command })
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

function M.create_matrix_power_node(base_matrix, exponent)
  return node("matrix_power", { base = base_matrix, exponent = exponent })
end

function M.create_identity_matrix_node(dimension_expr)
  return node("identity_matrix", { dimension = dimension_expr })
end

function M.create_zero_vector_matrix_node(dimensions_spec)
  return node("zero_vector_matrix", { dimensions = dimensions_spec })
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

function M.create_solve_system_node(equations_list, variables_list)
  return node("solve_system", { equations = equations_list, variables = variables_list })
end

return M
