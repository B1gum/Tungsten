-- lua/tungsten/domains/differential_equations/rules/ode.lua
-- Defines the lpeg rule for parsing ordinary differential equations (ODEs).

local lpeg = require "lpeg"
local P, V, Ct, Cg, Cmt = lpeg.P, lpeg.V, lpeg.Ct, lpeg.Cg, lpeg.Cmt

local tk = require "tungsten.core.tokenizer"
local ast = require "tungsten.core.ast"
local space = tk.space

local has_derivative_heuristic = Cmt(P(1)^0, function(s)
  return (string.find(s, "d", 1, true) or string.find(s, "'", 1, true)) ~= nil
end)

local ODERule = has_derivative_heuristic * Ct(Cg(V("ExpressionContent"), "lhs") * space * P"=" * space * Cg(V("ExpressionContent"), "rhs")) /
function(captures)
  return ast.create_ode_node(captures.lhs, captures.rhs)
end

return ODERule
