local lpeg = require("lpeglabel")
local P, V, C, S = lpeg.P, lpeg.V, lpeg.C, lpeg.S
local ast = require("tungsten.core.ast")
local tk = require("tungsten.core.tokenizer")

local UnitMacro = P("\\") * C(tk.letter ^ 1) / ast.create_unit_component_node
local UnitLiteral = C(tk.letter ^ 1) / ast.create_unit_component_node
local UnitItem = UnitMacro + UnitLiteral

local DotOp = (P(".") + P("*") + P("\\cdot")) * tk.space / function()
	return "*"
end
local PerOp = (P("\\per") + P("/")) * tk.space / function()
	return "/"
end
local UnitOp = DotOp + PerOp

local Caret = P("^") * tk.space
local LBrace = tk.lbrace
local RBrace = tk.rbrace

local function num_node(n)
	return ast.create_number_node(tonumber(n))
end

local function parse_si_num(str)
	local clean_str = str:gsub(",", ".")
	return tonumber(clean_str)
end

local ExpContent = lpeg.R("09") ^ 1 * (P(".") * lpeg.R("09") ^ 1) ^ -1
local ExplicitExp = Caret
	* ((LBrace * tk.space * C(S("+-") ^ -1 * ExpContent) * tk.space * RBrace) + C(ExpContent))
	/ num_node

local PostSquared = P("\\squared") * tk.space / function()
	return num_node(2)
end
local PostCubed = P("\\cubed") * tk.space / function()
	return num_node(3)
end
local PreSquare = P("\\square") * tk.space / function()
	return num_node(2)
end
local PreCube = P("\\cube") * tk.space / function()
	return num_node(3)
end

local PostMod = ExplicitExp + PostSquared + PostCubed
local PreMod = PreSquare + PreCube

local UnitExpr = P({
	"Expr",
	Expr = V("Term") * (UnitOp * V("Term")) ^ 0 / function(acc, ...)
		local args = { ... }
		for i = 1, #args, 2 do
			local op = args[i]
			local right = args[i + 1]
			acc = ast.create_binary_operation_node(op, acc, right)
		end
		return acc
	end,
	Term = ((PreMod + lpeg.Cc(nil)) * UnitItem * (PostMod + lpeg.Cc(nil))) / function(pre, item, post)
		local exponent = pre or post
		if exponent then
			return ast.create_superscript_node(item, exponent)
		end
		return item
	end,
})

local QtyCmd = P("\\qty")
local Content = (
	lpeg.R("09") ^ 1
	* (lpeg.S(".,") * lpeg.R("09") ^ 1) ^ -1
	* (lpeg.S("eE") * lpeg.S("+-") ^ -1 * lpeg.R("09") ^ 1) ^ -1
)
	/ parse_si_num
	/ ast.create_number_node

local QtyRule = QtyCmd
	* tk.space
	* LBrace
	* tk.space
	* Content
	* tk.space
	* RBrace
	* tk.space
	* LBrace
	* tk.space
	* UnitExpr
	* tk.space
	* RBrace
	/ ast.create_quantity_node

return QtyRule
