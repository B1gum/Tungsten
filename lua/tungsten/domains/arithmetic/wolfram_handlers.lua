local M = {}

local config = require('tungsten.config')

local op_attributes = {
  ["+"] = { prec = 1, assoc = "L", wolfram = "+" },
  ["-"] = { prec = 1, assoc = "L", wolfram = "-" },
  ["*"] = { prec = 2, assoc = "L", wolfram = "*" },
  ["/"] = { prec = 2, assoc = "L", wolfram = "/" },
  ["^"] = { prec = 3, assoc = "R", wolfram = "^" },
  ["=="] = { prec = 0, assoc = "N", wolfram = "==" },
  ["="] = { prec = 0, assoc = "N", wolfram = "==" },
  ["\\cdot"] = { prec = 2, assoc = "L", wolfram = "*" },
  ["\\times"] = { prec = 2, assoc = "L", wolfram = "*" },
}

local function bin_with_parens(node, recur_render)
  local parent_op_data = op_attributes[node.operator]

  if not parent_op_data then
    local logger = require "tungsten.util.logger"
    logger.warn("Tungsten", "Tungsten Wolfram Handler (bin_with_parens): Undefined operator '" .. tostring(node.operator) .. "'. Rendering directly without precedence.")
    local rendered_left_unknown = recur_render(node.left)
    local rendered_right_unknown = recur_render(node.right)
    return rendered_left_unknown .. " " .. node.operator .. " " .. rendered_right_unknown
  end

  local parent_prec_val = parent_op_data.prec
  local parent_assoc_val = parent_op_data.assoc
  local wolfram_op_display = parent_op_data.wolfram

  local function child_needs_parentheses(child_node, is_left_child_of_parent)
    if not child_node or child_node.type ~= "binary" then
      return false
    end

    local child_op_data = op_attributes[child_node.operator]

    if not child_op_data then
      return true
    end

    local child_prec_val = child_op_data.prec

    if child_prec_val < parent_prec_val then
      return true
    end

    if child_prec_val > parent_prec_val then
      return false
    end

    if parent_assoc_val == "N" then
        return true
    end

    if is_left_child_of_parent then
      return parent_assoc_val == "R"
    else
      return parent_assoc_val == "L"
    end
  end

  local rendered_left = recur_render(node.left)
  if child_needs_parentheses(node.left, true) then
    rendered_left = "(" .. rendered_left .. ")"
  end

  local rendered_right = recur_render(node.right)
  if child_needs_parentheses(node.right, false) then
    rendered_right = "(" .. rendered_right .. ")"
  end

  if wolfram_op_display == "^" then
    return string.format("Power[%s, %s]", rendered_left, rendered_right)
  end

  return rendered_left .. " " .. wolfram_op_display .. " " .. rendered_right
end

M.handlers = {
  number = function(node)
    return tostring(node.value)
  end,
  variable = function(node)
    return node.name
  end,
  greek = function(node)
    return node.name
  end,

  binary = bin_with_parens,

  fraction = function(node, recur_render)
    return string.format("(%s) / (%s)", recur_render(node.numerator), recur_render(node.denominator))
  end,
  sqrt = function(node, recur_render)
    if node.index then
      return ("Surd[%s, %s]"):format(recur_render(node.radicand), recur_render(node.index))
    else
      return ("Sqrt[%s]"):format(recur_render(node.radicand))
    end
  end,
  superscript = function(node, recur_render)
    local base_str = recur_render(node.base)
    local exp_str = recur_render(node.exponent)
    return ("Power[%s, %s]"):format(base_str, exp_str)
  end,
  subscript = function(node, recur_render)
    return ("Subscript[%s, %s]"):format(recur_render(node.base), recur_render(node.subscript))
  end,
  unary = function(node, recur_render)
    local operand_str = recur_render(node.value)
    if node.operator == "-" then
        if node.value.type == "binary" then
            return string.format("(-(%s))", operand_str)
        else
            return string.format("(-%s)", operand_str)
        end
    else
        return node.operator .. operand_str
    end
  end,
  function_call = function(node, recur_render)
    local func_name_map = config.wolfram_function_mappings or {}
    local func_name_str = (node.name_node and node.name_node.name) or "UnknownFunction"
    local wolfram_func_name = func_name_map[func_name_str:lower()]

    if not wolfram_func_name then
      wolfram_func_name = func_name_str:match("^%a") and (func_name_str:sub(1,1):upper() .. func_name_str:sub(2)) or func_name_str
      local logger = require "tungsten.util.logger"
      logger.warn("Tungsten", ("Tungsten Wolfram Handler: No specific mapping for function '%s'. Using form '%s'."):format(
          func_name_str, wolfram_func_name
        ))
    end

    local rendered_args = {}
    if node.args then
        for _, arg_node in ipairs(node.args) do
          table.insert(rendered_args, recur_render(arg_node))
        end
    end
    return ("%s[%s]"):format(wolfram_func_name, table.concat(rendered_args, ", "))
  end,

  solve_system = function(node, recur_render)
    local rendered_equations = {}
    for _, eq_node in ipairs(node.equations) do
      table.insert(rendered_equations, recur_render(eq_node))
    end

    local rendered_variables = {}
    for _, var_node in ipairs(node.variables) do
      table.insert(rendered_variables, recur_render(var_node))
    end

    local equations_str = "{" .. table.concat(rendered_equations, ", ") .. "}"
    local variables_str = "{" .. table.concat(rendered_variables, ", ") .. "}"

    return ("Solve[%s, %s]"):format(equations_str, variables_str)
  end,
}

return M
