-- lua/tungsten/domains/differential_equations/rules/ode.lua
-- Defines the lpeg rule for parsing ordinary differential equations (ODEs).

local lpeg = require("lpeglabel")
local P, V, Ct, Cg, Cmt = lpeg.P, lpeg.V, lpeg.Ct, lpeg.Cg, lpeg.Cmt

local tk = require("tungsten.core.tokenizer")
local ast = require("tungsten.core.ast")
local space = tk.space

local function is_point_derivative(node)
	return node.variable and node.variable.type == "number"
end

local function contains_derivative(node)
	if type(node) ~= "table" then
		return false
	end
	if node.type == "ordinary_derivative" and not is_point_derivative(node) then
		return true
	end
	if node.type == "partial_derivative" then
		return true
	end
	for _, v in pairs(node) do
		if contains_derivative(v) then
			return true
		end
	end
	return false
end

local main_rule =
	Ct(Cg(V("ExpressionContent"), "lhs") * space * tk.equals_op * space * Cg(V("ExpressionContent"), "rhs"))

local DifferentialEquationRule = Cmt(main_rule, function(_, pos, captures)
	if contains_derivative(captures.lhs) or contains_derivative(captures.rhs) then
		return pos, ast.create_ode_node(captures.lhs, captures.rhs)
	end
	return false
end)

return DifferentialEquationRule
