-- lua/tungsten/domains/calculus/rules/product.lua
-- Defines the lpeg rule for parsing product expressions e.g., \\prod_{i=0}^{N} i^2

local lpeg = vim.lpeg
local P, V, Cg, Ct = lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct

local tk = require("tungsten.core.tokenizer")
local space = tk.space
local ast = require("tungsten.core.ast")

local product_keyword = P("\\prod")

local subscript_marker = P("_")

local superscript_marker = P("^")

local equals_sign = P("=")

local variable_capture = Cg(tk.variable, "index_variable")
local start_expr_capture = Cg(V("Expression"), "start_expression")
local end_expr_capture = Cg(V("Expression"), "end_expression")
local body_expr_capture = Cg(V("Expression"), "body_expression")

local subscript_content_pattern = variable_capture * space * equals_sign * space * start_expr_capture

local full_subscript_pattern = subscript_marker
	* space
	* tk.lbrace
	* space
	* subscript_content_pattern
	* space
	* tk.rbrace

local full_superscript_pattern = superscript_marker * space * tk.lbrace * space * end_expr_capture * space * tk.rbrace

local main_body_expression_segment = space
	* ((tk.lbrace * space * body_expr_capture * space * tk.rbrace) + body_expr_capture)

local ProductRule = Ct(
	product_keyword * space * full_subscript_pattern * space * full_superscript_pattern * main_body_expression_segment
) / function(captures)
	return ast.create_product_node(
		captures.index_variable,
		captures.start_expression,
		captures.end_expression,
		captures.body_expression
	)
end

return ProductRule
