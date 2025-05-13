local lpeg = require "lpeg"
local Cf,S,Ct, C = lpeg.Cf, lpeg.S, lpeg.Ct, lpeg.C
local space   = require("parser.tokens").space
local MulDiv  = require("parser.rules.muldiv")
local make_bin = require("parser.ast").make_bin

local AddSub = Cf(
  MulDiv * (space * Ct( C(S("+-")) * space * MulDiv ))^0,
  function(acc, pair) return make_bin(pair[1], acc, pair[2]) end
)

return AddSub

