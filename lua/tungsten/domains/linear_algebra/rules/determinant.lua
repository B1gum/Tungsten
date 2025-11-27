-- tungsten/lua/tungsten/domains/linear_algebra/rules/determinant.lua
-- Defines the lpeg rule for parsing determinant expressions like |A| or \det(A).
--------------------------------------------------------------------------------

local lpeg = require("lpeglabel")
local V, Cg, Ct, P = lpeg.V, lpeg.Cg, lpeg.Ct, lpeg.P

local tk = require("tungsten.core.tokenizer")
local ast = require("tungsten.core.ast")
local space = tk.space

local function determinant_or_abs(expr_ast)
	return ast.create_determinant_node(expr_ast)
end

local DetCommandRule = Ct(
	tk.det_command * space * tk.lparen * space * Cg(V("Expression"), "expr_content") * space * tk.rparen
) / function(captures_table)
	return ast.create_determinant_node(captures_table.expr_content)
end

local SingleBar = (tk.vbar / function()
	return nil
end) + P("\\lvert") + P("\\rvert") + P("\\left|") + P("\\right|")

local VerticalBarRule = Ct(SingleBar * space * Cg(V("Expression"), "expr_content") * space * SingleBar)
	/ function(captures_table)
		return determinant_or_abs(captures_table.expr_content)
	end

local DeterminantRule = DetCommandRule + VerticalBarRule

return DeterminantRule
