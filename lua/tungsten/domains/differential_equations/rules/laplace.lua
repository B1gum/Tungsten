-- lua/tungsten/domains/differential_equations/rules/laplace.lua
-- Defines the lpeg rule for parsing Laplace transforms.

local lpeg = require "lpeg"
local P, V, C = lpeg.P, lpeg.V, lpeg.C

local tk = require "tungsten.core.tokenizer"
local ast = require "tungsten.core.ast"
local space = tk.space

local expression_in_braces = P"\\{" * space * V"Expression" * space * P"\\}"

local inverse_marker = P"^" * space * P"{" * space * P"-1" * space * P"}"

local LaplaceRule = P"\\mathcal{L}" * C(inverse_marker^-1) * space * expression_in_braces / function(inv, expr)
  if inv == "" then
    return ast.create_laplace_transform_node(expr)
  else
    return ast.create_inverse_laplace_transform_node(expr)
  end
end

return LaplaceRule
