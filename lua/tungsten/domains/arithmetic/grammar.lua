local lpeg = require "lpeg"
local V    = lpeg.V

local tokens     = require "tungsten.core.tokenizer"
local Fraction   = require "tungsten.domains.arithmetic.rules.fraction"
local Sqrt       = require "tungsten.domains.arithmetic.rules.sqrt"
local SS         = require "tungsten.domains.arithmetic.rules.supersub"
local SupSub     = SS.SupSub
local Unary      = SS.Unary
local MulDiv     = require "tungsten.domains.arithmetic.rules.muldiv"
local AddSub     = require "tungsten.domains.arithmetic.rules.addsub"

local AtomBase = Fraction + Sqrt
               + tokens.number + tokens.variable + tokens.Greek
               + tokens.lbrace * V("Expression") * tokens.rbrace
               + tokens.lparen * V("Expression") * tokens.rparen
               + tokens.lbrack * V("Expression") * tokens.rbrack

return lpeg.P{
  "Expression",
  Expression = AddSub,
  AtomBase   = AtomBase,
  SupSub     = SupSub,
  Unary      = Unary,
}

