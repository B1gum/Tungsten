local lpeg = require "lpeg"
local Cf,S,Ct, C = lpeg.Cf, lpeg.S, lpeg.Ct, lpeg.C
local space   = require "tungsten.core.tokenizer".space
local MulDiv  = require "tungsten.domains.arithmetic.rules.muldiv"
local create_binary_operation_node = require "tungsten.core.ast".create_binary_operation_node

local AddSub = Cf(
  MulDiv * (space * Ct( C(S("+-")) * space * MulDiv ))^0,
  function(acc, pair) return create_binary_operation_node(pair[1], acc, pair[2]) end
)

return AddSub

