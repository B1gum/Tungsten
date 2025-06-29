local lpeg = require "lpeg"
local Cf,S,Ct, C, V = lpeg.Cf, lpeg.S, lpeg.Ct, lpeg.C, lpeg.V -- Make sure V is included
local space   = require "tungsten.core.tokenizer".space
-- local MulDiv  = require "tungsten.domains.arithmetic.rules.muldiv" -- REMOVE THIS LINE
local create_binary_operation_node = require "tungsten.core.ast".create_binary_operation_node

local AddSub = Cf(
  V("MulDiv") * (space * Ct( C(S("+-")) * space * V("MulDiv") ))^0, -- USE V("MulDiv") HERE
  function(acc, pair) return create_binary_operation_node(pair[1], acc, pair[2]) end
)

return AddSub
