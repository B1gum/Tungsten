-- parser/LPeg_parser.lua
-- Parsing module for turning LaTeX-expressions into AST (with limits, Greek letters, function calls, and integrals)
----------------------------------------------------------
local lpeg = require("lpeg")
local AST = require("tungsten.parser.AST")

local P, R, S, V, C, Ct = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Ct

-- Update WS to include LaTeX spacing commands like "\,"
local WS = (S(" \t\r\n") + P("\\,"))^0       -- Global whitespace

----------------------------------------------------------
-- Basic elements: Numbers, Variables
----------------------------------------------------------
local digit = R("09")
local numberPattern = (P("-")^-1 * digit^1 * (P(".") * digit^1)^-1)
local Number = C(numberPattern) / function(str)
  return AST.Number(tonumber(str))
end

local Variable = C(R("az", "AZ")^1) / function(str)
  return AST.Variable(str)
end

----------------------------------------------------------
-- Unified constant definitions (non-Greek)
----------------------------------------------------------
local constant_defs = {
  { tex = "\\pi", value = "Pi" },
  { tex = "e",    value = "E" },
  { tex = "\\infty", value = "Infinity" },
  { tex = "-\\infty", value = "-Infinity" },
}

local Constant = nil
for i, def in ipairs(constant_defs) do
  local pat = P(def.tex) / function()
    return AST.Constant(def.value)
  end
  if not Constant then
    Constant = pat
  else
    Constant = Constant + pat
  end
end

----------------------------------------------------------
-- Greek letter definitions
----------------------------------------------------------
local greek_defs = {
  { tex = "\\alpha", value = "alpha" },
  { tex = "\\beta", value = "beta" },
  { tex = "\\gamma", value = "gamma" },
  { tex = "\\delta", value = "delta" },
  { tex = "\\epsilon", value = "epsilon" },
  { tex = "\\zeta", value = "zeta" },
  { tex = "\\eta", value = "eta" },
  { tex = "\\theta", value = "theta" },
  { tex = "\\iota", value = "iota" },
  { tex = "\\kappa", value = "kappa" },
  { tex = "\\lambda", value = "lambda" },
  { tex = "\\mu", value = "mu" },
  { tex = "\\nu", value = "nu" },
  { tex = "\\xi", value = "xi" },
  { tex = "\\omicron", value = "omicron" },
  { tex = "\\rho", value = "rho" },
  { tex = "\\sigma", value = "sigma" },
  { tex = "\\tau", value = "tau" },
  { tex = "\\upsilon", value = "upsilon" },
  { tex = "\\phi", value = "phi" },
  { tex = "\\chi", value = "chi" },
  { tex = "\\psi", value = "psi" },
  { tex = "\\omega", value = "omega" },
  -- Uppercase Greek letters:
  { tex = "\\Gamma", value = "Gamma" },
  { tex = "\\Delta", value = "Delta" },
  { tex = "\\Theta", value = "Theta" },
  { tex = "\\Lambda", value = "Lambda" },
  { tex = "\\Xi", value = "Xi" },
  { tex = "\\Pi", value = "Pi" },
  { tex = "\\Sigma", value = "Sigma" },
  { tex = "\\Upsilon", value = "Upsilon" },
  { tex = "\\Phi", value = "Phi" },
  { tex = "\\Psi", value = "Psi" },
  { tex = "\\Omega", value = "Omega" },
}

local Greek = nil
for i, def in ipairs(greek_defs) do
  local pat = P(def.tex) / function()
    return AST.Constant(def.value)
  end
  if not Greek then
    Greek = pat
  else
    Greek = Greek + pat
  end
end

----------------------------------------------------------
-- Limit Parsing Patterns
----------------------------------------------------------
local Direction = (P("^") * (P("{") * WS * C(P("+") + P("-")) * WS * P("}"))) +
                  (P("^") * C(P("+") + P("-")))
local LimitValue = (Number + Constant + Greek + Variable) * (Direction)^-1
  / function(val, dir) return val, dir end

local LimitSubscript = Ct(
  Variable * WS * P("\\to") * WS * LimitValue
)
  / function(tbl)
      local var   = tbl[1]
      local point = tbl[2]
      local dir   = tbl[3]
      return var, point, dir
    end

local LimitExpr = P("\\lim") * WS *
  P("_") * WS *
  P("{") * WS *
    LimitSubscript * WS *
  P("}") * WS *
  (P("{") * WS * V("Expr") * WS * P("}") + V("Expr"))
  / function(var, point, dir, expr)
      return AST.Limit(expr, var, point, dir)
    end

----------------------------------------------------------
-- Function Call Parsing Pattern
----------------------------------------------------------
local FunctionCall = (P("\\") * C(R("az", "AZ")^1)) * (P("(") * V("Expr") * P(")"))
  / function(fname, arg)
      local capName = fname:sub(1,1):upper() .. fname:sub(2)
      return AST.FunctionCall(capName, arg)
    end

----------------------------------------------------------
-- Differential Pattern
----------------------------------------------------------
-- Matches a differential marker: either "d" or "\mathrm{d}" (with its closing brace)
local DifferentialMarker = WS * (P("d") + (P("\\mathrm{") * P("d") * P("}")))

-- Differential: differential marker followed by a variable (e.g. d x)
local Differential = DifferentialMarker * WS * V("Variable")

----------------------------------------------------------
-- Integral Parsing Pattern (Ungrouped Integrand)
----------------------------------------------------------
-- Here, we capture the integrand as a substring that stops at the first occurrence of a differential.
-- Then we recursively parse that substring using parse_expr.
local Integral = P("\\int") * WS *
  -- Optional lower limit (must be grouped)
  (P("_") * WS * P("{") * WS * V("Expr") * WS * P("}"))^-1 *
  -- Optional upper limit (must be grouped)
  (P("^") * WS * P("{") * WS * V("Expr") * WS * P("}"))^-1 *
  -- Capture integrand as all characters up to the differential marker
  C((1 - DifferentialMarker)^1) *
  -- Optional differential (e.g. d x)
  (Differential)^-1
  / function(lower, upper, integrand_str, var)
       -- Trim whitespace from the captured integrand string.
       integrand_str = integrand_str:gsub("^%s+", ""):gsub("%s+$", "")
       -- Recursively parse the integrand string into an AST.
       local integrand_ast = require("tungsten.parser.LPeg_parser").parse_expr(integrand_str)
       return AST.Int(integrand_ast, var, lower, upper)
    end

----------------------------------------------------------
-- Other Constructs (Fractions, Derivatives, etc.)
----------------------------------------------------------
local Fraction = P("\\frac") * WS * P("{") * V("Expr") * P("}") * WS *
                 P("{") * V("Expr") * P("}")
                 / function(num, den)
                     return AST.Div(num, den)
                   end

local DerivSymbol = P("d") + (P("\\mathrm{") * P("d") * P("}"))
local Derivative = P("\\frac") * WS *
  P("{") * WS *
    (DerivSymbol * ((P("^") * C(numberPattern)) + C(""))) * WS * P("}") * WS *
  P("{") * WS *
    ((DerivSymbol)^-1 * V("Variable")) * WS * P("}") * WS *
  P("{") * WS * V("Expr") * WS * P("}")
  / function(numExp, var, expr)
      local order = 1
      if numExp ~= "" then order = tonumber(numExp) end
      return AST.Derivative(expr, var, order)
    end

local PartialDerivative = P("\\frac") * WS *
  P("{") * WS *
    (P("\\partial") * ((P("^") * C(numberPattern)) + C(""))) * WS * P("}") * WS *
  P("{") * WS *
    ((P("\\partial"))^-1 * V("Variable")) * WS * P("}") * WS *
  P("{") * WS * V("Expr") * WS * P("}")
  / function(numExp, var, expr)
      local order = 1
      if numExp ~= "" then order = tonumber(numExp) end
      return AST.PartialDerivative(expr, var, order)
    end

----------------------------------------------------------
-- Operators and Grouping
----------------------------------------------------------
local Plus    = C(P("+"))
local Minus   = C(P("-"))
local Mul     = C(P("*") + P("\\cdot"))
local Pow     = P("^")
local LParen  = P("(")
local RParen  = P(")")

local Factor = Ct(V("Atom")^1) / function(tbl)
  local nonNil = {}
  for i, v in ipairs(tbl) do
    if v ~= nil then table.insert(nonNil, v) end
  end
  if #nonNil == 0 then return nil end
  local node = nonNil[1]
  for i = 2, #nonNil do
    node = AST.Mul(node, nonNil[i])
  end
  return node
end

----------------------------------------------------------
-- Grammar
----------------------------------------------------------
local Grammar = P{
  "Expr",
  Expr = Ct(V("Term") * ((Plus + Minus) * V("Term"))^0)
         / function(tbl)
             local node = tbl[1]
             local i = 2
             while i < #tbl do
               local op = tbl[i]
               local rhs = tbl[i+1]
               if op == "+" then
                 node = AST.Add(node, rhs)
               else
                 node = AST.Sub(node, rhs)
               end
               i = i + 2
             end
             return node
           end,
  Term = Ct(V("Exponent") * ((WS * (Mul + Fraction) * WS) * V("Exponent"))^0)
         / function(tbl)
             local node = tbl[1]
             local i = 2
             while i < #tbl do
               local op = tbl[i]
               local rhs = tbl[i+1]
               if op == "*" or op == "\\cdot" then
                 node = AST.Mul(node, rhs)
               else
                 node = AST.Div(node, rhs)
               end
               i = i + 2
             end
             return node
           end,
  Exponent = V("Factor") * (Pow * V("Exponent"))^-1
             / function(base, exponent)
                 if exponent then return AST.Pow(base, exponent) else return base end
               end,
  Factor = Factor,
  -- Place Integral and FunctionCall at the beginning of Atom so they take precedence.
  Atom = Integral + FunctionCall + LimitExpr + Derivative + PartialDerivative + Fraction + Number + Greek + Constant + Variable + (LParen * V("Expr") * RParen),
  Derivative = Derivative,
  PartialDerivative = PartialDerivative,
  Fraction = Fraction,
  Number = Number,
  Variable = Variable,
  Constant = Constant,
}

local FullPattern = WS * Grammar * -1
local function parse_expr(input)
  local ast = FullPattern:match(input)
  if not ast then
    error("Parse Error: Invalid LaTeX expression")
  end
  return ast
end

return {
  parse_expr = parse_expr
}
