local lpeg = require "lpeg"
local Cf, C, S, P, V = lpeg.Cf, lpeg.C, lpeg.S, lpeg.P, lpeg.V

local tk = require "tungsten.core.tokenizer"
local space = tk.space
local ast = require "tungsten.core.ast"
local Unary = V("Unary")

local is_potential_differential_start = P("d") * space * tk.variable

local function is_vector_like(node)
  if not (node and node.type) then return false end
  if node.type == "symbolic_vector" or node.type == "vector" or node.type == "matrix" then
    return true
  end
  if node.type == "unary" and node.value then
    return is_vector_like(node.value)
  end
  return false
end

local ExplicitOpCapture = C(P("\\cdot") + P("\\times") + S("*/"))

local ExplicitOpAndTerm = space * ExplicitOpCapture * space * Unary / function(op_str, term_ast)
  return { operator_str = op_str, term = term_ast }
end

local ImplicitMulAndTerm = space * -S("+-*/") * -P("\\cdot") * -P("\\times") * -is_potential_differential_start * Unary / function(term_ast)
  return { operator_str = "*", term = term_ast, implicit = true }
end

local MulDiv = Cf(
  Unary * (ExplicitOpAndTerm + ImplicitMulAndTerm)^0,
  function(left_acc_ast, op_and_right_term)
    local op_str = op_and_right_term.operator_str
    local right_term_ast = op_and_right_term.term

    if op_str == "\\cdot" then
      if is_vector_like(left_acc_ast) and is_vector_like(right_term_ast) then
        return ast.create_dot_product_node(left_acc_ast, right_term_ast)
      else
        return ast.create_binary_operation_node("*", left_acc_ast, right_term_ast)
      end
    elseif op_str == "\\times" then
      if is_vector_like(left_acc_ast) and is_vector_like(right_term_ast) then
        return ast.create_cross_product_node(left_acc_ast, right_term_ast)
      else
        return ast.create_binary_operation_node("*", left_acc_ast, right_term_ast)
      end
    else
      return ast.create_binary_operation_node(op_str, left_acc_ast, right_term_ast)
    end
  end
)

return MulDiv

