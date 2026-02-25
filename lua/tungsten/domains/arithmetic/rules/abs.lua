local lpeg = vim.lpeg
local V, Cg, Ct, P = lpeg.V, lpeg.Cg, lpeg.Ct, lpeg.P

local tk = require("tungsten.core.tokenizer")
local ast = require("tungsten.core.ast")
local space = tk.space

local SingleBar = (tk.vbar / function()
	return nil
end) + P("\\lvert") + P("\\rvert") + P("\\left|") + P("\\right|")

local AbsRule = Ct(SingleBar * space * Cg(V("Expression"), "expr_content") * space * SingleBar)
	/ function(captures_table)
		return ast.create_abs_node(captures_table.expr_content)
	end

return AbsRule
