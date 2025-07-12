local lpeg = require "lpeglabel"
local P       = lpeg.P
local V       = lpeg.V
local tk      = require "tungsten.core.tokenizer"
local space   = tk.space
local lbrack  = tk.lbrack
local rbrack  = tk.rbrack
local lbrace  = tk.lbrace
local rbrace  = tk.rbrace
local ast    = require "tungsten.core.ast"

local Sqrt = P("\\sqrt")
  * (lbrack * space * V("Expression") * space * rbrack)^-1
  * lbrace * space * V("Expression") * space * rbrace
  / function(a, b)
      local idx, rad = b and a or nil, b or a
      return ast.create_sqrt_node(rad, idx)
    end

return Sqrt

