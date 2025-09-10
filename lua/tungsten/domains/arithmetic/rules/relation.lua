local lpeg = require("lpeglabel")
local P, C, V = lpeg.P, lpeg.C, lpeg.V

local tokens = require("tungsten.core.tokenizer")
local ast = require("tungsten.core.ast")

local space = tokens.space

local inequality_op = (P("&") ^ -1)
	* tokens.space
	* C(P("\\leq") + P("\\le") + P("<=") + P("\\geq") + P("\\ge") + P(">=") + P("≤") + P("≥") + P("<") + P(">"))

local op_map = {
	["\\le"] = "≤",
	["\\leq"] = "≤",
	["<="] = "≤",
	["≤"] = "≤",
	["\\ge"] = "≥",
	["\\geq"] = "≥",
	[">="] = "≥",
	["≥"] = "≥",
}

local Inequality = V("ExpressionContent")
	* space
	* inequality_op
	* space
	* V("ExpressionContent")
	/ function(lhs, op, rhs)
		local mapped = op_map[op] or op
		return ast.create_inequality_node(lhs, mapped, rhs)
	end

local Equality = V("ExpressionContent")
	* space
	* tokens.equals_op
	* space
	* V("ExpressionContent")
	/ function(lhs, _, rhs)
		return ast.create_equality_node(lhs, rhs)
	end

return {
	Equality = Equality,
	Inequality = Inequality,
}
