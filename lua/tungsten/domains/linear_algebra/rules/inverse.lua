-- lua/tungsten/domains/linear_algebra/rules/inverse.lua
local lpeg = require "lpeg"
local P, V = lpeg.P, lpeg.V

local tk = require "tungsten.core.tokenizer"
local space = tk.space
local ast = require "tungsten.core.ast"

local InverseExponentPattern = P("^") * space * P("{") * space * P("-") * space * P("1") * space * P("}")

local InverseRule = V("AtomBaseItem") * space * InverseExponentPattern / function(base)
  return ast.create_inverse_node(base)
end

return InverseRule
