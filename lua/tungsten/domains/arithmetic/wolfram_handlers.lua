local M = {}

local prec = { ["+"] = 1, ["-"] = 1, ["*"] = 2, ["/"] = 2, ["^"] = 3 }

local function bin_with_parens(node, recur_render)
  local op = node.operator
  local function par(child_node)
    if child_node.type == "binary" and prec[child_node.operator] and prec[op] and prec[child_node.operator] < prec[op] then
      return "(" .. recur_render(child_node) .. ")"
    else
      return recur_render(child_node)
    end
  end
  return par(node.left) .. op .. par(node.right)
end

M.handlers = {
  number = function(node) return tostring(node.value) end,
  variable = function(node) return node.name end,
  greek = function(node) return node.name end,
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
    if node.base.type == "variable" or node.base.type == "number" then
      return base_str .. "^" .. exp_str
    else
      return ("Power[%s,%s]"):format(base_str, exp_str)
    end
  end,
  subscript = function(node, recur_render)
    return ("Subscript[%s,%s]"):format(recur_render(node.base), recur_render(node.subscript))
  end,
  unary = function(node, recur_render)
    return node.operator .. recur_render(node.value)
  end,
}

 M.precedence = prec

return M
