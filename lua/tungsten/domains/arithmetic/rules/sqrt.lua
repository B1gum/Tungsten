local lpeg = require "lpeg"
local P       = lpeg.P
local V       = lpeg.V
local space   = require("tungsten.core.tokenizer").space
local lbrack  = require("tungsten.core.tokenizer").lbrack
local rbrack  = require("tungsten.core.tokenizer").rbrack
local lbrace  = require("tungsten.core.tokenizer").lbrace
local rbrace  = require("tungsten.core.tokenizer").rbrace
local node    = require("tungsten.core.ast").node

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

