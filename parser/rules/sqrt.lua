local lpeg = require "lpeg"
local P       = lpeg.P
local V       = lpeg.V
local space   = require("tungsten.parser.tokens").space
local lbrack  = require("tungsten.parser.tokens").lbrack
local rbrack  = require("tungsten.parser.tokens").rbrack
local lbrace  = require("tungsten.parser.tokens").lbrace
local rbrace  = require("tungsten.parser.tokens").rbrace
local node    = require("tungsten.parser.ast").node

local Sqrt = P("\\sqrt")
  * (lbrack * space * V("Expression") * space * rbrack)^-1
  * lbrace * space * V("Expression") * space * rbrace
  / function(a, b)
      local idx, rad = b and a or nil, b or a
      local t = { type = "sqrt", radicand = rad }
      if idx then t.index = idx end
      return t
    end

return Sqrt

