-- tungsten/lua/tungsten/domains/linear_algebra/rules/transpose.lua
local lpeg = require "lpeg"
local V = lpeg.V

local ast = require "tungsten.core.ast"
local TransposeFromSupSub = V("SupSub") / function(node)
  if node and node.type == "superscript" and node.base and node.exponent then
    local exp = node.exponent
    if not exp then return nil end

    if exp.type == "variable" and exp.name == "T" then
      return ast.create_transpose_node(node.base)
    end

    if exp.type == "intercal_command" then
      return ast.create_transpose_node(node.base)
    end

    if (exp.type == "variable" or exp.type == "greek") and (exp.name == "intercal" or exp.name == "\\intercal") then
      return ast.create_transpose_node(node.base)
    end

  end

  return nil
end

return TransposeFromSupSub
