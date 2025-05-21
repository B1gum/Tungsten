local lpeg   = require "lpeg"
local P,C,Cf,S,V = lpeg.P, lpeg.C, lpeg.Cf, lpeg.S, lpeg.V

local space  = require "tungsten.core.tokenizer".space
local ast    = require "tungsten.core.ast"

local Postfix = (P("^") * space * V("AtomBase")) / function(exp)
    return function(base)
      return ast.create_superscript_node(base, exp)
    end
  end
  + (P("_") * space * V("AtomBase")) / function(sub)
    return function(base)
      return ast.create_subscript_node(base, sub)
    end
  end

local SupSub = Cf(
  V("AtomBase") * (space * Postfix)^0,
  function(acc, fn) return fn(acc) end
)

local Unary = ( C(S("+-")) * space * V("SupSub") ) / function(op, expr)
    return ast.create_unary_operation_node(op, expr)
  end
  + V("SupSub")

return {
  SupSub = SupSub,
  Unary = Unary,
}

