local M = {}

------------------------------------------------------------------
-- precedence table ----------------------------------------------
------------------------------------------------------------------
local prec = { ["+"] = 1, ["-"] = 1, ["*"] = 2, ["/"] = 2, ["^"] = 3 }

------------------------------------------------------------------
-- forward declaration so both helpers can call each other -------
------------------------------------------------------------------
local emit   -- declare                                        ⇐  NEW
local function maybe_paren(child, parent_op)
  if child.type == "binary" and prec[child.operator] < prec[parent_op] then
    return "(" .. emit(child) .. ")"
  else
    return emit(child)
  end
end

------------------------------------------------------------------
-- recursive emitter (definition comes *after* the declaration) --
------------------------------------------------------------------
function emit(node)
  local t = node.type

  if t == "number"   then return tostring(node.value) end
  if t == "variable" then return node.name           end
  if t == "greek"    then return node.name           end

  if t == "binary" then
    local op    = node.operator
    local left  = maybe_paren(node.left,  op)
    local right = maybe_paren(node.right, op)
    return left .. op .. right
  end

  if t == "fraction" then
    return ("%s/(%s)"):format(emit(node.numerator), emit(node.denominator))
  end

  if t == "sqrt" then
    if node.index then
      return ("Surd[%s,%s]"):format(emit(node.radicand), emit(node.index))
    else
      return ("Sqrt[%s]"):format(emit(node.radicand))
    end
  end

  if t == "superscript" then
    local base = emit(node.base)
    local exp  = emit(node.exponent)
    if node.base.type == "variable" or node.base.type == "number" then
      return base .. "^" .. exp
    else
      return ("Power[%s,%s]"):format(base, exp)
    end
  end

  if t == "subscript" then
    return ("Subscript[%s,%s]"):format(emit(node.base), emit(node.subscript))
  end

  if t == "unary" then
    return node.operator .. emit(node.value)
  end

  error("unknown node type: " .. t)
end

------------------------------------------------------------------
-- public API -----------------------------------------------------
------------------------------------------------------------------
function M.to_string(ast)
  return emit(ast)
end

return M
