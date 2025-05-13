-- tungsten/backends/wolfram.lua
-- AST ➜ Wolfram Language string, now built on core.render (pure).

local render = require("tungsten.core.render")

----------------------------------------------------------------
-- precedence table so we know when to parenthesise
local prec = { ["+"] = 1, ["-"] = 1, ["*"] = 2, ["/"] = 2, ["^"] = 3 }

----------------------------------------------------------------
-- helpers
local function bin_with_parens(n, recur)
  local op = n.operator
  local function par(child)
    if child.type == "binary" and prec[child.operator] < prec[op] then
      return "(" .. recur(child) .. ")"
    else
      return recur(child)
    end
  end
  return par(n.left) .. op .. par(n.right)
end

----------------------------------------------------------------
-- handlers:  node.type → function(node, recur)
local H = {}

H["number"]   = function(n) return tostring(n.value) end
H["variable"] = function(n) return n.name end
H["greek"]    = function(n) return n.name end

H["binary"]   = bin_with_parens

H["fraction"] = function(n, r)
  return ("%s/(%s)"):format(r(n.numerator), r(n.denominator))
end

H["sqrt"] = function(n, r)
  if n.index then
    return ("Surd[%s,%s]"):format(r(n.radicand), r(n.index))
  else
    return ("Sqrt[%s]"):format(r(n.radicand))
  end
end

H["superscript"] = function(n, r)
  local base, exp = r(n.base), r(n.exponent)
  if n.base.type == "variable" or n.base.type == "number" then
    return base .. "^" .. exp
  else
    return ("Power[%s,%s]"):format(base, exp)
  end
end

H["subscript"] = function(n, r)
  return ("Subscript[%s,%s]"):format(r(n.base), r(n.subscript))
end

H["unary"] = function(n, r)
  return n.operator .. r(n.value)
end

----------------------------------------------------------------
-- public API
local M = {}

---@param ast table
---@return string
function M.to_string(ast)
  return render.render(ast, H)
end

return M

