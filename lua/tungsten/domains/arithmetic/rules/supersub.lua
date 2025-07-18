local lpeg = require("lpeglabel")
local P, V, C, Cf, S = lpeg.P, lpeg.V, lpeg.C, lpeg.Cf, lpeg.S

local tk = require("tungsten.core.tokenizer")
local space = tk.space
local ast = require("tungsten.core.ast")

local M = {}

local ExponentOrSubscriptContent = V("AtomBase")

local PostfixOperator = (
	P("^")
	* space
	* ExponentOrSubscriptContent
	/ function(exponent_ast)
		return function(base_ast)
			return ast.create_superscript_node(base_ast, exponent_ast)
		end
	end
)
	+ (
		P("_")
		* space
		* ExponentOrSubscriptContent
		/ function(subscript_ast)
			return function(base_ast)
				return ast.create_subscript_node(base_ast, subscript_ast)
			end
		end
	)

M.SupSub = Cf(V("AtomBase") * (space * PostfixOperator) ^ 0, function(accumulator_ast, operator_func)
	if operator_func then
		return operator_func(accumulator_ast)
	end
	return accumulator_ast
end)

M.Unary = (C(S("+-")) * space * M.SupSub) / function(op, expr)
	return ast.create_unary_operation_node(op, expr)
end + M.SupSub

return {
	SupSub = M.SupSub,
	Unary = M.Unary,
}
