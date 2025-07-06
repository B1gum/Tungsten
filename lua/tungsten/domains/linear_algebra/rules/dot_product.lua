-- lua/tungsten/domains/linear_algebra/rules/dot_product.lua
-- Defines the lpeg rule for parsing dot product expressions like a \cdot b
--------------------------------------------------------------------------

local lpeg = require "lpeg"
local V, Cg, Ct = lpeg.V, lpeg.Cg, lpeg.Ct

local tk = require "tungsten.core.tokenizer"
local space = tk.space
local ast = require "tungsten.core.ast"

local DotProductRule = Ct(
  Cg(V("Expression"), "left_vector") * space *
  tk.cdot_command * space *
  Cg(V("Expression"), "right_vector")
) / function(captures)
  return ast.create_dot_product_node(captures.left_vector, captures.right_vector)
end

return DotProductRule
