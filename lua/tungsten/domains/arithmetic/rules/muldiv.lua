local lpeg = require "lpeg"
local Cf,C,S = lpeg.Cf, lpeg.C, lpeg.S
local P       = lpeg.P
local space   = require("tungsten.core.tokenizer").space
local Unary   = require("tungsten.domains.arithmetic.rules.supersub").Unary
local make_bin = require("tungsten.core.ast").make_bin

local MulOpCap = (P("\\cdot") / function() return "*" end) + C(S("*/"))

local ImplicitMul = space * -S("+-") * Unary
  / function(rhs) return "*", rhs end

local MulDiv = Cf(
  Unary
  * (
       space * MulOpCap * space * Unary / function(op, rhs) return op, rhs end
     + ImplicitMul
    )^0,
  function(acc, op, rhs) return make_bin(op, acc, rhs) end
)

return MulDiv

