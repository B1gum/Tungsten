-- lua/tungsten/domains/linear_algebra/rules/vector.lua
-- Defines the lpeg rule for parsing \vec and \mathbf vector notations.
---------------------------------------------------------------------

local lpeg = require "lpeg"
local P, V, C, S = lpeg.P, lpeg.V, lpeg.C, lpeg.S

local tk = require "tungsten.core.tokenizer"
local ast = require "tungsten.core.ast"
local space = tk.space

local VecCommand = P("\\vec") * space * tk.lbrace * space * V("Expression") * space * tk.rbrace /
  function(expr_capture)
    return ast.create_symbolic_vector_node(expr_capture, "vec")
  end

local MathBoldCommand = P("\\mathbf") * space * tk.lbrace * space * V("Expression") * space * tk.rbrace /
  function(expr_capture)
    return ast.create_symbolic_vector_node(expr_capture, "mathbf")
  end

local VectorRule = VecCommand + MathBoldCommand

return VectorRule
