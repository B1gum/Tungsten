-- tungsten/lua/tungsten/domains/linear_algebra/rules/determinant.lua
-- Defines the lpeg rule for parsing determinant expressions like |A| or \det(A).
--------------------------------------------------------------------------------

local lpeg = require("lpeglabel")
local V, Cg, Ct, P = lpeg.V, lpeg.Cg, lpeg.Ct, lpeg.P

local tk = require("tungsten.core.tokenizer")
local ast = require("tungsten.core.ast")
local space = tk.space

local function is_matrix_like(node)
	return type(node) == "table" and node.type == "matrix"
end

local function is_symbolic_matrix(node)
	if type(node) ~= "table" then
		return false
	end
	if (node.type == "variable" or node.type == "symbol" or node.type == "greek") and type(node.name) == "string" then
		return node.name:match("^[A-Z]") ~= nil
	end
	if node.type == "function_call" then
		return is_symbolic_matrix(node.name_node)
	end
	return false
end

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
