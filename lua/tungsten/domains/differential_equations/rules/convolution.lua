-- lua/tungsten/domains/differential_equations/rules/convolution.lua
-- Defines the lpeg rule for parsing convolutions.

local lpeg = require "lpeglabel"
local Cf, V, P, Ct, C = lpeg.Cf, lpeg.V, lpeg.P, lpeg.Ct, lpeg.C
local space = require("tungsten.core.tokenizer").space
local ast = require "tungsten.core.ast"

local higher_precedence_rule = V "Unary"

local operator = C(P"\\ast")

local ConvolutionPattern = Cf(higher_precedence_rule * (space * Ct(operator * space * higher_precedence_rule))^0,
  function(acc, pair)
    if not pair then
      return acc
    end
    return ast.create_convolution_node(acc, pair[2])
  end
)

return ConvolutionPattern
