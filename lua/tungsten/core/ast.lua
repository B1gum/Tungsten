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
  if op == "\\cdot" then op = "*" end -- Normalize \cdot to *
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

return M
