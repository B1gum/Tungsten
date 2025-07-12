-- lua/tungsten/domains/linear_algebra/rules/cross_product.lua
-- Defines the lpeg rule for parsing cross product expressions like a \times b
--------------------------------------------------------------------------

local lpeg = require "lpeglabel"
local V, Cg, Ct = lpeg.V, lpeg.Cg, lpeg.Ct

local tk = require "tungsten.core.tokenizer"
local space = tk.space
local ast = require "tungsten.core.ast"

local CrossProductRule = Ct(
  Cg(V("Expression"), "left_vector") * space *
  tk.times_command * space *
  Cg(V("Expression"), "right_vector")
) / function(captures)
  return ast.create_cross_product_node(captures.left_vector, captures.right_vector)
end

return CrossProductRule
