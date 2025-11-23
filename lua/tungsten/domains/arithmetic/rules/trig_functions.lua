local lpeg = require("lpeglabel")
local P, V = lpeg.P, lpeg.V
local tk = require("tungsten.core.tokenizer")
local space = (type(tk) == "table" and tk.space) or require("lpeglabel").S(" \t\n\r") ^ 0
local ast = require("tungsten.core.ast")

local Unary = V("Unary")

local function trig_rule(cmd, name)
	return P(cmd)
		* space
		* (tk.lparen * space * V("Expression") * space * tk.rparen + tk.lbrace * space * V("Expression") * space * tk.rbrace + Unary)
		/ function(arg_expr)
			local func_name_node = ast.create_variable_node(name)
			return ast.create_function_call_node(func_name_node, { arg_expr })
		end
end

return {
	SinRule = trig_rule("\\sin", "sin"),
	CosRule = trig_rule("\\cos", "cos"),
	TanRule = trig_rule("\\tan", "tan"),
}
