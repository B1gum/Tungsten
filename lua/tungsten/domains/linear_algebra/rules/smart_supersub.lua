-- tungsten/lua/tungsten/domains/linear_algebra/rules/smart_supersub.lua
local lpeg = require "lpeg"
local P, V, C, Cf, S = lpeg.P, lpeg.V, lpeg.C, lpeg.Cf, lpeg.S

local tk = require "tungsten.core.tokenizer"
local space = tk.space
local ast = require "tungsten.core.ast"

local M = {}

local function is_matrix_or_vector(node)
  if not (node and node.type) then return false end
  if node.type == "matrix" or node.type == "symbolic_vector" or node.type == "vector" then
    return true
  end
  if node.type == "subscript" and node.base then
    return is_matrix_or_vector(node.base)
  end
  if node.type == "unary" and node.value then
     return is_matrix_or_vector(node.value)
  end
  return false
end

local ExponentOrSubscriptContent = V("AtomBase")

local PostfixOperator =
  (P("^") * space * ExponentOrSubscriptContent / function(exponent_ast)
    return function(base_ast)
      if is_matrix_or_vector(base_ast) then
        if exponent_ast.type == "variable" and exponent_ast.name == "T" then
          return ast.create_transpose_node(base_ast)
        end
        if exponent_ast.type == "intercal_command" then
          return ast.create_transpose_node(base_ast)
        end
      end

      local base_can_be_inverted = base_ast.type == "matrix" or
                                  base_ast.type == "symbolic_vector" or
                                  base_ast.type == "vector"

      if base_can_be_inverted then
        if (exponent_ast.type == "number" and exponent_ast.value == -1) or
           (exponent_ast.type == "unary" and exponent_ast.operator == "-" and
            exponent_ast.value and exponent_ast.value.type == "number" and exponent_ast.value.value == 1) then
          return ast.create_inverse_node(base_ast)
        end
      end

      return ast.create_superscript_node(base_ast, exponent_ast)
    end
  end) +
  (P("_") * space * ExponentOrSubscriptContent / function(subscript_ast)
    return function(base_ast)
      return ast.create_subscript_node(base_ast, subscript_ast)
    end
  end)

M.SmartSupSub = Cf(
  V("AtomBase") * (space * PostfixOperator)^0,
  function(accumulator_ast, operator_func)
    if operator_func then
      return operator_func(accumulator_ast)
    end
    return accumulator_ast
  end
)

M.SmartUnary = ( C(S("+-")) * space * M.SmartSupSub ) / function(op, expr)
    return ast.create_unary_operation_node(op, expr)
  end
  + M.SmartSupSub

return M
