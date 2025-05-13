local lpeg = require "lpeg"
local Cf,S,Ct, C = lpeg.Cf, lpeg.S, lpeg.Ct, lpeg.C
local space   = require("tungsten.parser.tokens").space
local MulDiv  = require("tungsten.parser.rules.muldiv")
local make_bin = require("tungsten.parser.ast").make_bin

local AddSub = Cf(
  MulDiv * (space * Ct( C(S("+-")) * space * MulDiv ))^0,
  function(acc, pair) return make_bin(pair[1], acc, pair[2]) end
)

return AddSub

