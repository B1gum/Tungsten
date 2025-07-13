-- lua/tungsten/domains/differential_equations/wolfram_handlers.lua

local M = {}

local function find_ode_vars(equation_nodes)
  local dependent_vars = {}
  local independent_vars = {}
  local seen_dependent = {}
  local seen_independent = {}

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

        table.insert(dependent_vars, func_name_str .. "[" .. indep_name .. "]")
        seen_dependent[func_name_str] = true

        if not seen_independent[indep_name] then
          table.insert(independent_vars, indep_name)
          seen_independent[indep_name] = true
        end
      end
    elseif node.type == "variable" and not seen_dependent[node.name] then
         if node.name ~= 'x' and node.name ~= 't' then
            table.insert(dependent_vars, node.name .. "[x]")
            seen_dependent[node.name] = true
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

  return table.concat(dependent_vars, ", "), table.concat(independent_vars, ", ")
end



M.handlers = {
    ["ordinary_derivative"] = function(node, walk)
      local order = (node.order and node.order.value) or 1
      local variable_str = (node.variable and walk(node.variable)) or "x"

      if node.expression.type == "function_call" then
        local func_name = walk(node.expression.name_node)
        local prime_str = string.rep("'", order)
        local arg_str = walk(node.expression.args[1])
        return func_name .. prime_str .. "[" .. arg_str .. "]"
      elseif node.expression.type == "variable" then
        local func_name = walk(node.expression)
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
        local equation_str = walk(node.lhs) .. " == " .. walk(node.rhs)
        local vars_str, indep_vars_str = find_ode_vars({ node })
        return "DSolve[" .. equation_str .. ", " .. vars_str .. ", " .. indep_vars_str .. "]"
    end,

    ["ode_system"] = function(node, walk)
        local rendered_odes = {}
        for _, ode_node in ipairs(node.equations) do
            table.insert(rendered_odes, walk(ode_node.lhs) .. " == " .. walk(ode_node.rhs))
        end
        local equations_str = "{" .. table.concat(rendered_odes, ", ") .. "}"
        local vars_str, indep_vars_str = find_ode_vars(node.equations)
        return "DSolve[" .. equations_str .. ", {" .. vars_str .. "}, " .. indep_vars_str .. "]"
    end,


    ["solve_system_equations_capture"] = function(node, walk)
        local rendered_equations = {}
        for _, eq_node in ipairs(node.equations) do
            table.insert(rendered_equations, walk(eq_node))
        end
        local equations_str = "{" .. table.concat(rendered_equations, ", ") .. "}"
        local vars_str, indep_vars_str = find_ode_vars(node.equations)

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
        local rendered_functions = {}
        for _, func_node in ipairs(node.functions) do
            table.insert(rendered_functions, walk(func_node))
        end
        local funcs_str = "{" .. table.concat(rendered_functions, ", ") .. "}"
        local var_str = (node.variable and walk(node.variable)) or "x"
        return "Wronskian[" .. funcs_str .. ", " .. var_str .. "]"
    end,
}

return M
