local lpeg = require "lpeg"
local V    = lpeg.V

-- import the pieces
local tokens     = require "parser.tokens"
local Fraction   = require "parser.rules.fraction"
local Sqrt       = require "parser.rules.sqrt"
local SupSub     = require "parser.rules.supersub".SupSub
local Unary      = require "parser.rules.supersub".Unary
local MulDiv     = require "parser.rules.muldiv"
local AddSub     = require "parser.rules.addsub"

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

