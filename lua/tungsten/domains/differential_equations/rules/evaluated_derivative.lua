-- lua/tungsten/domains/differential_equations/rules/evaluated_derivative.lua
-- Defines the lpeg rule for parsing evaluated derivatives like y'(0).

local lpeg = require "lpeg"
local P, S, V, C, Cc, Cg, Ct = lpeg.P, lpeg.S, lpeg.V, lpeg.C, lpeg.Cc, lpeg.Cg, lpeg.Ct
local ast = require "tungsten.core.ast"
local tk = require "tungsten.core.tokenizer"
local space = tk.space

local Apostrophes = C(P"'" * P"'" * P"'") / function() return 3 end
  + C(P"'" * P"'") / function() return 2 end
  + C(P"'") / function() return 1 end

local EvaluatedDerivativeRule = Ct(
  Cg(V "Variable", "func_name")
    * Cg(Apostrophes, "order")
    * space
    * P "("
    * space
    * Cg(V "Expression", "point")
    * space
    * P ")"
) / function(captures)
  return ast.create_evaluated_derivative_node(captures.func_name, captures.point, captures.order)
end

return EvaluatedDerivativeRule
