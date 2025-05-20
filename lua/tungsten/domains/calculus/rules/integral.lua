-- tungsten/lua/tungsten/domains/calculus/rules/integral.lua
-- Defines the lpeg rule for parsing integral expressions, both indefinite and definite.

local lpeg = require "lpeg"
local P, V, Cg, Ct = lpeg.P, lpeg.V, lpeg.Cg, lpeg.Ct

local tk = require("tungsten.core.tokenizer")
local space = tk.space -- Reminder: tk.space is S(" \t\n\r")^0
local node = require("tungsten.core.ast").node

local integral_keyword = P("\\int")

local integrand_capture = Cg(V("Expression"), "integrand")

local d_operator = P("\\mathrm{d}") + P("d")
local var_of_int_cg = Cg(tk.variable, "variable_of_integration_val")

local base_differential = d_operator * space * var_of_int_cg

local latex_spacing_macro = P("\\,") + P("\\.") + P("\\;")
local optional_latex_spacer_followed_by_space = (latex_spacing_macro * space)^-1
local differential_segment = optional_latex_spacer_followed_by_space * base_differential

local lower_bound_capture = Cg(V("Expression"), "lower_bound")
local upper_bound_capture = Cg(V("Expression"), "upper_bound")

local subscript_for_lower_bound =
  P("_") * space *
  tk.lbrace * space * lower_bound_capture * space * tk.rbrace

local superscript_for_upper_bound =
  P("^") * space *
  tk.lbrace * space * upper_bound_capture * space * tk.rbrace

local indefinite_integral_structure =
  integral_keyword * space *
  integrand_capture *
  space *
  differential_segment

local IndefiniteIntegralRule =
  Ct(indefinite_integral_structure) / function(captures)
    return node("indefinite_integral", {
      integrand = captures.integrand,
      variable = captures.variable_of_integration_val
    })
  end

local definite_integral_structure =
  integral_keyword * space *
  subscript_for_lower_bound * space *
  superscript_for_upper_bound * space *
  integrand_capture *
  space *
  differential_segment

local DefiniteIntegralRule =
  Ct(definite_integral_structure) / function(captures)
    return node("definite_integral", {
      integrand = captures.integrand,
      variable = captures.variable_of_integration_val,
      lower_bound = captures.lower_bound,
      upper_bound = captures.upper_bound
    })
  end

local IntegralRule = DefiniteIntegralRule + IndefiniteIntegralRule

return IntegralRule
