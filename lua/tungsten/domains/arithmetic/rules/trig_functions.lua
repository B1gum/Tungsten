local lpeg = require "lpeglabel"
local P, V = lpeg.P, lpeg.V
local tk    = require "tungsten.core.tokenizer"
local space = (type(tk) == "table" and tk.space)
           or  require "lpeglabel".S(" \t\n\r")^0
local ast = require "tungsten.core.ast"

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
