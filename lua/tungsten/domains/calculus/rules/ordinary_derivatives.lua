-- lua/tungsten/domains/calculus/rules/ordinary_derivatives.lua
-- Defines the lpeg rule for parsing ordinary derivatives like \frac{d}{dx} f(x)

local lpeg = require "lpeg"
local P, V, Cg, Ct = lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct

local tk = require("tungsten.core.tokenizer")
local space = tk.space
local node = require("tungsten.core.ast").node

local d_operator_match = P("\\mathrm{d}") + P("d")

local variable_of_diff_capture_cg = Cg(tk.variable, "variable")

local order_content_atom = V("AtomBase")

local flexible_order_capture = Cg( (tk.lbrace * space * order_content_atom * space * tk.rbrace) + order_content_atom, "order")
local superscript_part_capturing_order = P("^") * space * flexible_order_capture

local superscript_part_for_denominator_var_match = P("^") * space * ( (tk.lbrace * space * order_content_atom * space * tk.rbrace) + order_content_atom )

local expression_to_diff_capture = Cg(V("Expression"), "expression")

local denominator_variable_part = d_operator_match * space * variable_of_diff_capture_cg
local denominator_segment_full = denominator_variable_part * superscript_part_for_denominator_var_match
local denominator_segment_simple = denominator_variable_part

local higher_order_derivative_frac_structure =
  P("\\frac") * space *
  tk.lbrace * space *
    d_operator_match * superscript_part_capturing_order *
  space * tk.rbrace *
  space *
  tk.lbrace * space *
    denominator_segment_full *
  space * tk.rbrace

local first_order_derivative_frac_structure =
  P("\\frac") * space *
  tk.lbrace * space *
    d_operator_match *
  space * tk.rbrace *
  space *
  tk.lbrace * space *
    denominator_segment_simple *
  space * tk.rbrace

local following_expression_segment = space * expression_to_diff_capture

local ordinary_derivative_higher_order_rule =
  Ct(higher_order_derivative_frac_structure * following_expression_segment) / function(captures)
    return node("ordinary_derivative", {
      expression = captures.expression,
      variable = captures.variable,
      order = captures.order
    })
  end

local ordinary_derivative_first_order_rule =
  Ct(first_order_derivative_frac_structure * following_expression_segment) / function(captures)
    return node("ordinary_derivative", {
      expression = captures.expression,
      variable = captures.variable,
      order = { type = "number", value = 1 }
    })
  end

local OrdinaryDerivative = ordinary_derivative_higher_order_rule + ordinary_derivative_first_order_rule

return OrdinaryDerivative
