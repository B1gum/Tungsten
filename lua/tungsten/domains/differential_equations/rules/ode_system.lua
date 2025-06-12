-- lua/tungsten/domains/differential_equations/rules/ode_system.lua
-- Defines the lpeg rule for parsing a system of ODEs.

local lpeg = require "lpeg"
local P, S, V, Ct = lpeg.P, lpeg.S, lpeg.V, lpeg.Ct

local tk = require "tungsten.core.tokenizer"
local ast = require "tungsten.core.ast"
local space = tk.space

local separator = space * (P(";") + P"\\\\") * space

local ODESystemRule = Ct(V"ODE" * (separator * V"ODE")^0) / function(odes)
  return ast.create_ode_system_node(odes)
end

return ODESystemRule
