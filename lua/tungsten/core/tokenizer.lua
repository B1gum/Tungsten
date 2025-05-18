-- core/tokenizer.lua
-- Defines fundamental tokens for parser
------------------------------------------
local lpeg = require "lpeg"
local P,R,S = lpeg.P, lpeg.R, lpeg.S
local C = lpeg.C

local space = S(" \t\n\r")^0

local digit    = R("09")
local letter   = R("az","AZ")
local number   = C(digit^1 * (P(".") * digit^1)^-1) / function(n)
  return {type="number", value=tonumber(n)}
end
local variable = C(letter * (letter + digit)^0) / function(v)
  return {type="variable", name=v}
end

local greek_list = {"alpha","beta","gamma","delta","epsilon","zeta","eta","theta","iota","kappa","lambda","mu","nu","xi","pi","rho","sigma","tau","upsilon","phi","chi","psi","omega"}
local greek_pat = P(false)
for _,name in ipairs(greek_list) do
  greek_pat = greek_pat + P("\\"..name)
end
local Greek = C(greek_pat) / function(g)
  return { type="greek", name = g:sub(2) }
end

local lbrace, rbrace = P("{"), P("}")
local lparen, rparen = P("("), P(")")
local lbrack, rbrack = P("["), P("]")

return {
  space    = space,
  digit    = digit,
  letter   = letter,
  number   = number,
  variable = variable,
  Greek    = Greek,
  lbrace   = lbrace,
  rbrace   = rbrace,
  lparen   = lparen,
  rparen   = rparen,
  lbrack   = lbrack,
  rbrack   = rbrack,
}

