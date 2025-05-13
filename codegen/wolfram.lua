-- Translates Tungsten AST trees to Wolfram‑language source
-----------------------------------------------------------

local M = {}

--— operator mapping: TeX → Wolfram infix
local op_map = {
  ["+"]      = "+",
  ["-"]      = "-",
  ["*"]      = "*",
  ["/"]      = "/",
  ["^"]      = "^",
  ["\\cdot"] = "*",
}

-- Recursive translator --------------------------------------------------------
local function emit(node)
  -- Primitive Lua values ------------------------------------------------------
  if type(node) == "number" or type(node) == "string" then
    return tostring(node)
  end

  -- Explicit AST nodes --------------------------------------------------------
  if node.type == "number" then
    return tostring(node.value)
  elseif node.type == "binary" then
    local op   = op_map[node.operator] or error("unknown operator: " .. node.operator)
    local left = emit(node.left)
    local right= emit(node.right)
    return "(" .. left .. " " .. op .. " " .. right .. ")"
  elseif node.type == "unary" then
    return "(" .. node.operator .. emit(node.operand) .. ")"
  elseif node.type == "funcall" then
    local args = {}
    for i, a in ipairs(node.args) do args[i] = emit(a) end
    return node.name .. "[" .. table.concat(args, ",") .. "]"
  else
    error("unknown AST node type: " .. tostring(node.type))
  end
end

-- public API ------------------------------------------------------------------
function M.toWolfram(ast)        -- main entry point
  return emit(ast)
end

return M
