local lpeg   = require "lpeg"
local P,C,Cf,S,V = lpeg.P, lpeg.C, lpeg.Cf, lpeg.S, lpeg.V

local space  = require("tungsten.parser.tokens").space
local node   = require("tungsten.parser.ast").node

-- postfix factories
local Postfix = (P("^") * space * V("AtomBase")) / function(exp)
    return function(base)
      return node("superscript", { base = base, exponent = exp })
    end
  end
  + (P("_") * space * V("AtomBase")) / function(sub)
    return function(base)
      return node("subscript", { base = base, subscript = sub })
    end
  end

-- apply them
local SupSub = Cf(
  V("AtomBase") * (space * Postfix)^0,
  function(acc, fn) return fn(acc) end
)

-- unary ±
local Unary = ( C(S("+-")) * space * V("SupSub") ) / function(op, expr)
    return node("unary", { operator = op, value = expr })
  end
  + V("SupSub")

return {
  SupSub = SupSub,
  Unary = Unary,
}

