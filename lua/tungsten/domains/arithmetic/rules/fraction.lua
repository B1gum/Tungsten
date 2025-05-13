local lpeg = require "lpeg"
local P       = lpeg.P
local V       = lpeg.V
local space   = require("tungsten.core.tokenizer").space
local lbrace  = require("tungsten.core.tokenizer").lbrace
local rbrace  = require("tungsten.core.tokenizer").rbrace
local node    = require("tungsten.core.ast").node

local Fraction = P("\\frac") * space
  * lbrace * space * V("Expression") * space * rbrace
  * lbrace * space * V("Expression") * space * rbrace
  / function(num, den)
      return node("fraction", { numerator = num, denominator = den })
    end

return Fraction
