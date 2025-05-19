-- core/ast.lua
-- Utility functions for creating AST nodes
----------------------------------------------

local function node(t, fields)
  fields.type = t
  return fields
end

local function create_binary_operation_node(op, left, right)
  if op == "\\cdot" then op = "*" end
  return node("binary", { operator = op, left = left, right = right })
end

return {
  node    = node,
  create_binary_operation_node = create_binary_operation_node,
}
