-- tungsten/lua/tungsten/domains/arithmetic/grammar.lua

local lpeg = require "lpeg"
local P, V = lpeg.P, lpeg.V
local tokens = require "tungsten.core.tokenizer"
local ast_utils = require "tungsten.core.ast"

local minimal_equation_debug_pattern = P("=") / function()
  if _G.enable_tungsten_parser_debug then
    print("[DEBUG] MinimalEquationDebugRule's action invoked for input '='.")
  end
  return { type = "debug_minimal_equals_matched" }
end

local standard_equation_pattern = (V("ExpressionContent") * tokens.equals_op * V("ExpressionContent")) / function(lhs, op, rhs)
  return ast_utils.create_binary_operation_node("=", lhs, rhs)
end

local current_equation_rule
if _G.enable_tungsten_parser_debug then
  current_equation_rule = minimal_equation_debug_pattern
else
  current_equation_rule = standard_equation_pattern
end

local AddSub     = require "tungsten.domains.arithmetic.rules.addsub"
local expression_content_rule = AddSub

local Fraction   = require "tungsten.domains.arithmetic.rules.fraction"
local Sqrt       = require "tungsten.domains.arithmetic.rules.sqrt"
local SS_rules   = require "tungsten.domains.arithmetic.rules.supersub"
local SupSub     = SS_rules.SupSub
local Unary      = SS_rules.Unary

local AtomBaseUserItems = Fraction + Sqrt + tokens.number + tokens.variable + tokens.Greek
local TrigFunctionRules = require("tungsten.domains.arithmetic.rules.trig_functions")
AtomBaseUserItems = AtomBaseUserItems + TrigFunctionRules.SinRule

local AtomBase = AtomBaseUserItems +
                 (tokens.lbrace * V("ExpressionContent") * tokens.rbrace) +
                 (tokens.lparen * V("ExpressionContent") * tokens.rparen) +
                 (tokens.lbrack * V("ExpressionContent") * tokens.rbrack)

return lpeg.P{
  "TopLevel",

  TopLevel = V("Equation") + V("ExpressionContent"),

  Equation = current_equation_rule,

  ExpressionContent = expression_content_rule,

  AtomBase   = AtomBase,
  SupSub     = SupSub,
  Unary      = Unary,
}
