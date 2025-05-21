-- tungsten/lua/tungsten/domains/arithmetic/rules/muldiv.lua
local lpeg = require "lpeg"
local Cf,C,S = lpeg.Cf, lpeg.C, lpeg.S
local P       = lpeg.P

local tk = require "tungsten.core.tokenizer"
local space = tk.space
local variable_token = tk.variable

local Unary   = require "tungsten.domains.arithmetic.rules.supersub".Unary
local create_binary_operation_node = require "tungsten.core.ast".create_binary_operation_node

local d_char_pattern = P("d")
local is_potential_differential_start = d_char_pattern * space * variable_token

local MulOpCap = (P("\\cdot") / function() return "*" end) + C(S("*/"))

local ImplicitMul = space * -S("+-") * -is_potential_differential_start * Unary
  / function(rhs) return "*", rhs end

local MulDiv = Cf(
  Unary
  * (
       space * MulOpCap * space * Unary / function(op, rhs) return op, rhs end
     + ImplicitMul
    )^0,
  function(acc, op_capture, rhs_capture)
    return create_binary_operation_node(op_capture, acc, rhs_capture)
  end
)

return MulDiv
