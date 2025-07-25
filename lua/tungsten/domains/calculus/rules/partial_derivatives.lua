-- lua/tungsten/domains/calculus/rules/partial_derivatives.lua
-- Defines the lpeg rule for parsing partial derivative expressions.

local lpeg = require("lpeglabel")
local P, V, Cg, Ct = lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct

local tk = require("tungsten.core.tokenizer")
local space = tk.space
local ast = require("tungsten.core.ast")

local partial_op_symbol = P("\\partial")

local expression_body_capture = Cg(V("Expression"), "expression")
local main_expression_segment = space
	* ((tk.lbrace * space * expression_body_capture * space * tk.rbrace) + expression_body_capture)

local overall_order_content_atom = V("AtomBase")
local overall_order_exponent_capture = P("^")
	* space
	* Cg(
		(tk.lbrace * space * overall_order_content_atom * space * tk.rbrace) + overall_order_content_atom,
		"overall_order_val"
	)

local numerator_content_first_order = partial_op_symbol
local numerator_content_higher_order = partial_op_symbol * space * overall_order_exponent_capture

local denominator_variable_order_content = V("AtomBase")
local denominator_variable_exponent_optional = (
	P("^")
	* space
	* (
		(tk.lbrace * space * Cg(denominator_variable_order_content, "term_order") * space * tk.rbrace)
		+ Cg(denominator_variable_order_content, "term_order")
	)
) ^ -1

local single_denominator_differentiation_term = Ct(
	partial_op_symbol * space * Cg(tk.variable, "variable_name") * space * denominator_variable_exponent_optional
) / function(term_captures)
	return ast.create_differentiation_term_node(term_captures.variable_name, term_captures.term_order)
end

local denominator_differentiation_terms_list = Cg(
	Ct(single_denominator_differentiation_term * (space * single_denominator_differentiation_term) ^ 0),
	"variables_list"
)

local partial_derivative_frac_first_order = P("\\frac")
	* space
	* tk.lbrace
	* space
	* numerator_content_first_order
	* space
	* tk.rbrace
	* space
	* tk.lbrace
	* space
	* denominator_differentiation_terms_list
	* space
	* tk.rbrace

local PartialDerivativeRule_FirstOrder = Ct(partial_derivative_frac_first_order * main_expression_segment)
	/ function(captures)
		return ast.create_partial_derivative_node(captures.expression, ast.create_number_node(1), captures.variables_list)
	end

local partial_derivative_frac_higher_order = P("\\frac")
	* space
	* tk.lbrace
	* space
	* numerator_content_higher_order
	* space
	* tk.rbrace
	* space
	* tk.lbrace
	* space
	* denominator_differentiation_terms_list
	* space
	* tk.rbrace

local PartialDerivativeRule_HigherOrder = Ct(partial_derivative_frac_higher_order * main_expression_segment)
	/ function(captures)
		return ast.create_partial_derivative_node(captures.expression, captures.overall_order_val, captures.variables_list)
	end

local PartialDerivativeRule = PartialDerivativeRule_HigherOrder + PartialDerivativeRule_FirstOrder

return PartialDerivativeRule
