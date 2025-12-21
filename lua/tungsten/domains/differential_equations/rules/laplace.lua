-- lua/tungsten/domains/differential_equations/rules/laplace.lua
-- Defines the lpeg rule for parsing Laplace transforms.

local lpeg = require("lpeglabel")
local P, V, C = lpeg.P, lpeg.V, lpeg.C

local tk = require("tungsten.core.tokenizer")
local ast = require("tungsten.core.ast")
local space = tk.space

local function expression_in_delimiters(open_pattern, close_pattern)
	return open_pattern * space * V("Expression") * space * close_pattern
end

local expression_in_braces = expression_in_delimiters(P("\\{"), P("\\}"))
local expression_in_parens = expression_in_delimiters(P("("), P(")"))
local expression_in_left_right_braces = expression_in_delimiters(
	P("\\left") * space * P("\\{"),
	P("\\right") * space * P("\\}")
)
local expression_in_left_right_parens = expression_in_delimiters(
	P("\\left") * space * P("("),
	P("\\right") * space * P(")")
)

local expression_with_delimiters = expression_in_left_right_parens
	+ expression_in_left_right_braces
	+ expression_in_braces
	+ expression_in_parens

local inverse_marker = P("^") * space * P("{") * space * P("-1") * space * P("}")

local LaplaceRule = P("\\mathcal{L}")
	* C(inverse_marker ^ -1)
	* space
	* expression_with_delimiters
	/ function(inv, expr)
		if inv == "" then
			return ast.create_laplace_transform_node(expr)
		else
			return ast.create_inverse_laplace_transform_node(expr)
		end
	end

return LaplaceRule
