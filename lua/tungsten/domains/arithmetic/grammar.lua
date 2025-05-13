local lpeg = require "lpeg"
local V    = lpeg.V

-- import the pieces
local tokens     = require "tungsten.core.tokenizer"
local Fraction   = require "tungsten.domains.arithmetic.rules.fraction"
local Sqrt       = require "tungsten.domains.arithmetic.rules.sqrt"
local SupSub     = require "tungsten.domains.arithmetic.rules.supersub".SupSub
local Unary      = require "tungsten.domains.arithmetic.rules.supersub".Unary
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

