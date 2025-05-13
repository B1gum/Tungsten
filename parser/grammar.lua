local lpeg = require "lpeg"
local V    = lpeg.V

-- import the pieces
local tokens     = require "tungsten.parser.tokens"
local Fraction   = require "tungsten.parser.rules.fraction"
local Sqrt       = require "tungsten.parser.rules.sqrt"
local SupSub     = require "tungsten.parser.rules.supersub".SupSub
local Unary      = require "tungsten.parser.rules.supersub".Unary
local MulDiv     = require "tungsten.parser.rules.muldiv"
local AddSub     = require "tungsten.parser.rules.addsub"

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

