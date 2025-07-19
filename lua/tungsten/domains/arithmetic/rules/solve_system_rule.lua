-- lua/tungsten/domains/arithmetic/rules/solve_system_rule.lua
local lpeg = require("lpeglabel")
local P, V, Ct = lpeg.P, lpeg.V, lpeg.Ct

local tk = require("tungsten.core.tokenizer")
local space = tk.space

local SingleEquation = V("EquationRule")

local EquationSeparator = space * (P("\\\\") + P(";")) * space
local EquationList = Ct(SingleEquation * (EquationSeparator * SingleEquation) ^ 1)

local SolveSystemEquationsPattern = EquationList

local ast = require("tungsten.core.ast")

local SolveSystemRule = SolveSystemEquationsPattern
	/ function(captured_equations_table)
		return ast.create_solve_system_equations_capture_node(captured_equations_table)
	end

return SolveSystemRule
