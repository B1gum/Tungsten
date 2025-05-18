-- tungsten/core/render.lua  
-- Traverses an AST and converts it into a string representation
-- using table of handlers
--------------------------------------------------------------------
local M = {}

local function _walk(node, handlers)
  if type(node) ~= "table" then
    return tostring(node)
  end

  local tag = node.type
  if not tag then
    error("render.walk: node missing tag/type field")
  end

  local h = handlers[tag]
  if not h then
    error('render.walk: no handler for tag "' .. tostring(tag) .. '"')
  end

  return h(node, function(child)
    return _walk(child, handlers)
  end)
end

function M.render(ast, handlers)
  assert(type(handlers) == "table", "render.render: handlers must be a table")
  return _walk(ast, handlers)
end

return M

