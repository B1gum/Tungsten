local lpeg = vim.lpeg
local P = lpeg.P
local V = lpeg.V
local tk = require("tungsten.core.tokenizer")
local space = tk.space
local lbrace = tk.lbrace
local rbrace = tk.rbrace
local ast = require("tungsten.core.ast")

local Fraction = P("\\frac")
	* space
	* lbrace
	* space
	* V("Expression")
	* space
	* rbrace
	* lbrace
	* space
	* V("Expression")
	* space
	* rbrace
	/ function(num, den)
		return ast.create_fraction_node(num, den)
	end

return Fraction
