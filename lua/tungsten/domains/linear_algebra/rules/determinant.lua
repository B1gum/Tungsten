-- tungsten/lua/tungsten/domains/linear_algebra/rules/determinant.lua
-- Defines the lpeg rule for parsing determinant expressions like |A| or \det(A).
--------------------------------------------------------------------------------

local lpeg = require "lpeg"
local P, V, Cg, Ct = lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct

local tk = require "tungsten.core.tokenizer"
local ast = require "tungsten.core.ast"
local space = tk.space

local DetCommandRule =
  Ct(
    tk.det_command * space *
    tk.lparen * space *
    Cg(V("Expression"), "expr_content") * space *
    tk.rparen
  ) / function(captures_table)
    return ast.create_determinant_node(captures_table.expr_content)
  end

local VerticalBarRule =
  Ct(
    tk.vbar * space *
    Cg(V("Expression"), "expr_content") * space *
    tk.vbar
  ) / function(captures_table)
    return ast.create_determinant_node(captures_table.expr_content)
  end

local DeterminantRule = DetCommandRule + VerticalBarRule

return DeterminantRule
