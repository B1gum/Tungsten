local M = {}

local prec = { ["+"] = 1, ["-"] = 1, ["*"] = 2, ["/"] = 2, ["^"] = 3 }

local assoc = {
  ["+"] = "L",
  ["-"] = "L",
  ["*"] = "L",
  ["/"] = "L",
  ["^"] = "R"
}

local function bin_with_parens(node, recur_render)
  local parent_op = node.operator
  local parent_prec_val = prec[parent_op]
  local parent_assoc_val = assoc[parent_op]

  local function child_needs_parentheses(child_node, is_left_child_of_parent)
    if child_node.type ~= "binary" then
      return false
    end

    local child_op = child_node.operator
    local child_prec_val = prec[child_op]

    if not parent_prec_val or not child_prec_val then
      return true
    end

    if child_prec_val < parent_prec_val then
      return true
    end

    if child_prec_val > parent_prec_val then
      return false
    end

    if child_prec_val == parent_prec_val then
      if is_left_child_of_parent then
        return parent_assoc_val == "R"
      else
        return parent_assoc_val == "L"
      end
    end

    return false
  end

  local rendered_left = recur_render(node.left)
  if child_needs_parentheses(node.left, true) then
    rendered_left = "(" .. rendered_left .. ")"
  end

  local rendered_right = recur_render(node.right)
  if child_needs_parentheses(node.right, false) then
    rendered_right = "(" .. rendered_right .. ")"
  end

  return rendered_left .. parent_op .. rendered_right
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
    return ("(%s)/(%s)"):format(recur_render(node.numerator), recur_render(node.denominator))
  end,
  sqrt = function(node, recur_render)
    if node.index then
      return ("Surd[%s,%s]"):format(recur_render(node.radicand), recur_render(node.index))
    else
      return ("Sqrt[%s]"):format(recur_render(node.radicand))
    end
  end,
  superscript = function(node, recur_render)
    local base_str = recur_render(node.base)
    local exp_str = recur_render(node.exponent)
    if node.base.type == "variable" or node.base.type == "number" or node.base.type == "greek" then
      return base_str .. "^" .. exp_str
    else
      return ("Power[%s,%s]"):format(base_str, exp_str)
    end
  end,
  subscript = function(node, recur_render)
    return ("Subscript[%s,%s]"):format(recur_render(node.base), recur_render(node.subscript))
  end,
  unary = function(node, recur_render)
    local value_str = recur_render(node.value)
    if node.value.type == "binary" and (node.value.operator == "+" or node.value.operator == "-") then
         return node.operator .. "(" .. value_str .. ")"
    end
    return node.operator .. value_str
  end,
  function_call = function(node, recur_render)
    local func_name_map = {
      sin = "Sin",
      cos = "Cos",
      tan = "Tan",
      arcsin = "ArcSin",
      arccos = "ArcCos",
      arctan = "ArcTan",
      sinh = "Sinh",
      cosh = "Cosh",
      tanh = "Tanh",
      arsinh = "ArcSinh",
      arcosh = "ArcCosh",
      artanh = "ArcTanh",
      log = "Log",
      ln = "Log",
      log10 = "Log10",
      exp = "Exp",
    }
    local func_name_str = node.name_node.name
    local wolfram_func_name = func_name_map[func_name_str:lower()]

    if not wolfram_func_name then
      local logger = require "tungsten.util.logger"
      logger.notify(
        ("Tungsten: No specific wolfram mapping for function '%s'. Using capitalized form '%s'."):format(
          func_name_str,
          func_name_str:sub(1,1):upper() .. func_name_str:sub(2)
        ),
        logger.levels.WARN
      )
      wolfram_func_name = func_name_str:sub(1,1):upper() .. func_name_str:sub(2)
    end
    
    local rendered_args = {}
    for _, arg_node in ipairs(node.args) do
      table.insert(rendered_args, recur_render(arg_node))
    end

  return ("%s[%s]"):format(wolfram_func_name, table.concat(rendered_args, ", "))
  end
}

M.precedence = prec

return M
