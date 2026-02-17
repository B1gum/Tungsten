-- lua/tungsten/domains/calculus/rules/limit.lua
-- Defines the lpeg rule for parsing limit expressions like \lim_{x \to 0} f(x)

local lpeg = vim.lpeg
local P, V, Cg, Ct = lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct

local tk = require("tungsten.core.tokenizer")
local space = tk.space
local ast = require("tungsten.core.ast")

local lim_keyword = P("\\lim")

local subscript_marker = P("_")

local arrow_token = P("\\to")

local variable_capture = Cg(tk.variable, "variable")

local point_capture = Cg(V("Expression"), "point")
local expression_body_capture = Cg(V("Expression"), "expression")

local subscript_content_pattern = variable_capture * space * arrow_token * space * point_capture

local full_subscript_pattern = subscript_marker
	* space
	* tk.lbrace
	* space
	* subscript_content_pattern
	* space
	* tk.rbrace

local main_expression_segment = space
	* ((tk.lbrace * space * expression_body_capture * space * tk.rbrace) + expression_body_capture)

local LimitRule = Ct(lim_keyword * space * full_subscript_pattern * main_expression_segment)
	/ function(captures)
		return ast.create_limit_node(captures.variable, captures.point, captures.expression)
	end

return LimitRule
