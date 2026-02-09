local lpeg = require("lpeglabel")
local P = lpeg.P
local V = lpeg.V
local tk = require("tungsten.core.tokenizer")
local space = tk.space
local lbrace = tk.lbrace
local rbrace = tk.rbrace
local ast = require("tungsten.core.ast")

local Binomial = P("\\binom")
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
	/ function(n, k)
		return ast.create_binomial_node(n, k)
	end

return Binomial
