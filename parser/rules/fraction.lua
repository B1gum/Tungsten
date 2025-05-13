local lpeg = require "lpeg"
local P       = lpeg.P
local V       = lpeg.V
local space   = require("tungsten.parser.tokens").space
local lbrace  = require("tungsten.parser.tokens").lbrace
local rbrace  = require("tungsten.parser.tokens").rbrace
local node    = require("tungsten.parser.ast").node

local Fraction = P("\\frac") * space
  * lbrace * space * V("Expression") * space * rbrace
  * lbrace * space * V("Expression") * space * rbrace
  / function(num, den)
      return node("fraction", { numerator = num, denominator = den })
    end

return Fraction
