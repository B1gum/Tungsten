-- tungsten/core/render.lua  
-- Traverses an AST and converts it into a string representation
-- using table of handlers
--------------------------------------------------------------------
local M = {}

---@alias RenderHandler fun(node:table, render:fun(child:table):string):string
---@class RenderHandlers : table<string, RenderHandler>

-- internal tail‑recursive walker ---------------------------------
local function _walk(node, handlers)
  if type(node) ~= "table" then            -- numeric leaf, plain string …
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

  return h(node, function(child)           -- expose recurser to handlers
    return _walk(child, handlers)
  end)
end

---Render an AST with the given handlers.
---@param ast table
---@param handlers RenderHandlers
---@return string
function M.render(ast, handlers)
  assert(type(handlers) == "table", "render.render: handlers must be a table")
  return _walk(ast, handlers)
end

return M

