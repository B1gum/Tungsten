local lpeg = require "lpeg"
local P       = lpeg.P
local V       = lpeg.V
local tk      = require("tungsten.core.tokenizer")
local space   = tk.space
local lbrace  = tk.lbrace
local rbrace  = tk.rbrace
local node    = require("tungsten.core.ast").node

local Fraction = P("\\frac") * space
  * lbrace * space * V("Expression") * space * rbrace
  * lbrace * space * V("Expression") * space * rbrace
  / function(num, den)
      return node("fraction", { numerator = num, denominator = den })
    end

return Fraction
