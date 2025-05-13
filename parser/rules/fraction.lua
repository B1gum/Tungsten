local lpeg = require "lpeg"
local P       = lpeg.P
local V       = lpeg.V
local space   = require("parser.tokens").space
local lbrace  = require("parser.tokens").lbrace
local rbrace  = require("parser.tokens").rbrace
local node    = require("parser.ast").node

local Fraction = P("\\frac") * space
  * lbrace * space * V("Expression") * space * rbrace
  * lbrace * space * V("Expression") * space * rbrace
  / function(num, den)
      return node("fraction", { numerator = num, denominator = den })
    end

return Fraction
