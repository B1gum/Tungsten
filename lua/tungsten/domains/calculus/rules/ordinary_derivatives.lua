-- lua/tungsten/domains/calculus/rules/ordinary_derivatives.lua
-- Defines the lpeg rule for parsing ordinary derivatives including Leibniz, Lagrange, and Newton notations.

local lpeg = require("lpeglabel")
local P, V, C, Ct, Cg = lpeg.P, lpeg.V, lpeg.C, lpeg.Ct, lpeg.Cg
local tk = require("tungsten.core.tokenizer")
local space = tk.space
local ast = require("tungsten.core.ast")

local d_operator_match = P("\\mathrm{d}") + P("d")
local variable_of_diff_capture_cg = Cg(tk.variable, "variable")
local order_content_atom = V("AtomBase")
local flexible_order_capture =
	Cg((tk.lbrace * space * order_content_atom * space * tk.rbrace) + order_content_atom, "order")
local superscript_part_capturing_order = P("^") * space * flexible_order_capture
local expression_to_diff_capture = Cg(V("Expression"), "expression")
local parenthesized_expression_capture = tk.lparen * space * expression_to_diff_capture * space * tk.rparen
local denominator_variable_part = d_operator_match * space * variable_of_diff_capture_cg
local denominator_segment_full = denominator_variable_part * (P("^") * space * order_content_atom)
local denominator_segment_simple = denominator_variable_part

local higher_order_derivative_frac_structure = P("\\frac")
	* space
	* tk.lbrace
	* space
	* d_operator_match
	* superscript_part_capturing_order
	* space
	* tk.rbrace
	* space
	* tk.lbrace
	* space
	* denominator_segment_full
	* space
	* tk.rbrace

local higher_order_derivative_frac_structure_with_numerator_expr = P("\\frac")
	* space
	* tk.lbrace
	* space
	* d_operator_match
	* superscript_part_capturing_order
	* space
	* expression_to_diff_capture
	* space
	* tk.rbrace
	* space
	* tk.lbrace
	* space
	* denominator_segment_full
	* space
	* tk.rbrace

local first_order_derivative_frac_structure = P("\\frac")
	* space
	* tk.lbrace
	* space
	* d_operator_match
	* space
	* tk.rbrace
	* space
	* tk.lbrace
	* space
	* denominator_segment_simple
	* space
	* tk.rbrace

local first_order_derivative_frac_structure_with_numerator_expr = P("\\frac")
	* space
	* tk.lbrace
	* space
	* d_operator_match
	* space
	* expression_to_diff_capture
	* space
	* tk.rbrace
	* space
	* tk.lbrace
	* space
	* denominator_segment_simple
	* space
	* tk.rbrace

local following_expression_segment = space * expression_to_diff_capture

local leibniz_higher_order_rule_with_parentheses = Ct(
	higher_order_derivative_frac_structure * space * parenthesized_expression_capture
) / function(captures)
	return ast.create_ordinary_derivative_node(captures.expression, captures.variable, captures.order)
end

local leibniz_higher_order_rule_with_numerator = Ct(higher_order_derivative_frac_structure_with_numerator_expr)
	/ function(captures)
		return ast.create_ordinary_derivative_node(captures.expression, captures.variable, captures.order)
	end

local leibniz_higher_order_rule = Ct(higher_order_derivative_frac_structure * following_expression_segment)
	/ function(captures)
		return ast.create_ordinary_derivative_node(captures.expression, captures.variable, captures.order)
	end

local leibniz_first_order_rule_with_parentheses = Ct(
	first_order_derivative_frac_structure * space * parenthesized_expression_capture
) / function(captures)
	return ast.create_ordinary_derivative_node(captures.expression, captures.variable, nil)
end

local leibniz_first_order_rule_with_numerator = Ct(first_order_derivative_frac_structure_with_numerator_expr)
	/ function(captures)
		return ast.create_ordinary_derivative_node(captures.expression, captures.variable, nil)
	end

local leibniz_first_order_rule = Ct(first_order_derivative_frac_structure * following_expression_segment)
	/ function(captures)
		return ast.create_ordinary_derivative_node(captures.expression, captures.variable, nil)
	end

local LeibnizNotation = leibniz_higher_order_rule_with_parentheses
	+ leibniz_higher_order_rule_with_numerator
	+ leibniz_higher_order_rule
	+ leibniz_first_order_rule_with_parentheses
	+ leibniz_first_order_rule_with_numerator
	+ leibniz_first_order_rule

local func_identifier = tk.variable
local primes = C(P("'") ^ 1)
local args = tk.lparen * space * Cg(V("Expression"), "arg") * space * tk.rparen

local lagrange_infix_notation = Ct(Cg(func_identifier, "func_name") * Cg(primes, "primes") * args)
	/ function(captures)
		local order = #captures.primes
		local expression = ast.create_function_call_node(captures.func_name, { captures.arg })
		local variable = captures.arg
		return ast.create_ordinary_derivative_node(expression, variable, ast.create_number_node(order))
	end

local lagrange_postfix_notation = Ct(tk.variable * C(P("'") ^ 1))
	/ function(t)
		local var_name = t[1]
		local order = #t[2]
		local derivative_node =
			ast.create_ordinary_derivative_node(var_name, ast.create_variable_node("x"), ast.create_number_node(order))
		return derivative_node
	end

local LagrangeNotation = lagrange_infix_notation + lagrange_postfix_notation

local newton_dot = (P("\\ddot") / function()
	return 2
end) + (P("\\dot") / function()
	return 1
end)
local newton_notation = Ct(newton_dot * ((tk.lbrace * space * V("AtomBase") * space * tk.rbrace) + V("AtomBase")))
	/ function(captures)
		local order = captures[1]
		local base_expr = captures[2]
		return ast.create_ordinary_derivative_node(base_expr, ast.create_variable_node("t"), ast.create_number_node(order))
	end

local OrdinaryDerivative = LeibnizNotation + LagrangeNotation + newton_notation

return OrdinaryDerivative
