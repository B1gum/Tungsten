local lpeg = require "lpeg"
local P, V = lpeg.P, lpeg.V
local space = require("tungsten.core.tokenizer").space
local ast = require("tungsten.core.ast")

local M = {}

M.SinRule = P("\\sin") * space * V("Expression") / function(arg_expr)
  local func_name_node = { type = "variable", name = "sin" }
  return ast.create_function_call_node(func_name_node, { arg_expr })
end

M.CosRule = P("\\cos") * space * V("Expression") / function(arg_expr)
  local func_name_node = { type = "variable", name = "cos" }
  return ast.create_function_call_node(func_name_node, { arg_expr })
end

M.TanRule = P("\\tan") * space * V("Expression") / function(arg_expr)
  local func_name_node = { type = "variable", name = "tan" }
  return ast.create_function_call_node(func_name_node, { arg_expr })
end

return M
