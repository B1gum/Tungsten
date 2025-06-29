-- lua/tungsten/domains/calculus/wolfram_handlers.lua
-- Wolfram Language handlers for calculus operations
---------------------------------------------------------------------

local M = {}

M.handlers = {
  ordinary_derivative = function(node, walk)
    local order = (node.order and walk(node.order)) or 1
    local expression_str = walk(node.expression)
    local variable_str = walk(node.variable)

    if tostring(order) == "1" then
      return "D[" .. expression_str .. ", " .. variable_str .. "]"
    else
      return "D[" .. expression_str .. ", {" .. variable_str .. ", " .. tostring(order) .. "}]"
    end
  end,

  partial_derivative = function(node, recur_render)
    local expr_str = recur_render(node.expression)
    local vars_rendered = {}

    for _, var_node_info in ipairs(node.variables) do
      local var_name_str = recur_render(var_node_info.variable)
      local var_order_str = recur_render(var_node_info.order)
      if var_order_str == "1" then
        table.insert(vars_rendered, var_name_str)
      else
        table.insert(vars_rendered, ("{%s, %s}"):format(var_name_str, var_order_str))
      end
    end

    return ("D[%s, %s]"):format(expr_str, table.concat(vars_rendered, ", "))
  end,

  limit = function(node, recur_render)
    local expr_str = recur_render(node.expression)
    local var_str = recur_render(node.variable)
    local point_str = recur_render(node.point)
    return ("Limit[%s, %s -> %s]"):format(expr_str, var_str, point_str)
  end,

  indefinite_integral = function(node, recur_render)
    local integrand_str = recur_render(node.integrand)
    local var_str = recur_render(node.variable)
    return ("Integrate[%s, %s]"):format(integrand_str, var_str)
  end,

  definite_integral = function(node, recur_render)
    local integrand_str = recur_render(node.integrand)
    local var_str = recur_render(node.variable)
    local lower_bound_str = recur_render(node.lower_bound)
    local upper_bound_str = recur_render(node.upper_bound)
    return ("Integrate[%s, {%s, %s, %s}]"):format(integrand_str, var_str, lower_bound_str, upper_bound_str)
  end,

  summation = function(node, recur_render)
    local body_str = recur_render(node.body_expression)
    local index_var_str = recur_render(node.index_variable)
    local start_str = recur_render(node.start_expression)
    local end_str = recur_render(node.end_expression)
    return ("Sum[%s, {%s, %s, %s}]"):format(body_str, index_var_str, start_str, end_str)
  end,

  symbol = function(node, recur_render)
    if node.name == "infinity" then
      return "Infinity"
    elseif node.name == "pi" then
      return "Pi"
    else
      return node.name
    end
  end,
}

return M
