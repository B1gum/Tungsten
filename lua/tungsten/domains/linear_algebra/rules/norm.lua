-- lua/tungsten/domains/linear_algebra/rules/norm.lua
-- Defines the lpeg rule for parsing norm expressions like ||A|| or ||v||_p
--------------------------------------------------------------------------

local lpeg = require "lpeglabel"
local P, V, Cg, Ct = lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct

local tk = require "tungsten.core.tokenizer"
local space = tk.space
local ast = require "tungsten.core.ast"

local optional_subscript = (
  P("_") * space *
  (
    tk.lbrace * space * Cg(V("Expression"), "subscript_val") * space * tk.rbrace +
    Cg(V("AtomBase"), "subscript_val")
  )
)^-1

local DoublePipeNormRule = Ct(
  tk.double_pipe_norm * space *
  Cg(V("Expression"), "expression_val") * space *
  tk.double_pipe_norm * space *
  optional_subscript
) / function(captures)
  return ast.create_norm_node(captures.expression_val, captures.subscript_val)
end

local NormDelimiterCmdRule = Ct(
  tk.norm_delimiter_cmd * space *
  Cg(V("Expression"), "expression_val") * space *
  tk.norm_delimiter_cmd * space *
  optional_subscript
) / function(captures)
  return ast.create_norm_node(captures.expression_val, captures.subscript_val)
end

local NormRule = DoublePipeNormRule + NormDelimiterCmdRule

return NormRule
