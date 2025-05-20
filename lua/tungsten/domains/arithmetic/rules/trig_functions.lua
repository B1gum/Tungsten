-- tungsten/lua/tungsten/domains/arithmetic/rules/trig_functions.lua
local lpeg = require "lpeg"
local P, V = lpeg.P, lpeg.V
local space = require("tungsten.core.tokenizer").space
local ast_utils = require("tungsten.core.ast")

local M = {}

M.SinRule = P("\\sin") * space * V("Expression") / function(arg_expr)
  return ast_utils.node("function_call", {
    name_node = { type = "variable", name = "sin" },
    args = { arg_expr }
  })
end

M.CosRule = P("\\cos") * space * V("Expression") / function(arg_expr)
  return ast_utils.node("function_call", {
    name_node = { type = "variable", name = "cos" },
    args = { arg_expr }
  })
end

M.TanRule = P("\\tan") * space * V("Expression") / function(arg_expr)
  return ast_utils.node("function_call", {
    name_node = { type = "variable", name = "tan" },
    args = { arg_expr }
  })
end

return M
