-- lua/tungsten/domains/differential_equations/rules/wronskian.lua
-- Defines the lpeg rule for parsing the Wronskian.

local lpeg = require("lpeglabel")
local P, V, Ct = lpeg.P, lpeg.V, lpeg.Ct

local tk = require("tungsten.core.tokenizer")
local ast = require("tungsten.core.ast")
local space = tk.space

local expression_list = Ct(V("Expression") * (space * P(",") * space * V("Expression")) ^ 0)

local WronskianRule = P("W")
	* space
	* P("(")
	* space
	* expression_list
	* space
	* P(")")
	/ function(functions)
		return ast.create_wronskian_node(functions)
	end

return WronskianRule
