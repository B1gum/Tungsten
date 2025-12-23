-- tungsten/lua/tungsten/domains/linear_algebra/rules/determinant.lua
-- Defines the lpeg rule for parsing determinant expressions like |A| or \det(A).
--------------------------------------------------------------------------------

local lpeg = require("lpeglabel")
local V, Cg, Ct, P = lpeg.V, lpeg.Cg, lpeg.Ct, lpeg.P

local tk = require("tungsten.core.tokenizer")
local ast = require("tungsten.core.ast")
local space = tk.space

local function is_matrix_or_vector(node)
	if type(node) ~= "table" then
		return false
	end
	if node.type == "matrix" or node.type == "vector" or node.type == "symbolic_vector" then
		return true
	end
	if node.type == "subscript" and node.base then
		return is_matrix_or_vector(node.base)
	end
	if node.type == "unary" and node.value then
		return is_matrix_or_vector(node.value)
	end
	if node.type == "superscript" and node.base then
		return is_matrix_or_vector(node.base)
	end
	return false
end

local function determinant_or_abs(expr_ast)
	if is_matrix_or_vector(expr_ast) then
		return ast.create_norm_node(expr_ast, nil)
	end
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
