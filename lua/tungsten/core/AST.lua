-- core/ast.lua
-- Utility functions for creating AST nodes
----------------------------------------------

local function node(t, fields)
  fields.type = t
  return fields
end

local function make_bin(op, left, right)
  if op == "\\cdot" then op = "*" end
  return node("binary", { operator = op, left = left, right = right })
end

return {
  node    = node,
  make_bin = make_bin,
}
