local lpeg = require("lpeglabel")
local P, V, Cg, Cs = lpeg.P, lpeg.V, lpeg.Cg, lpeg.Cs
local tk = require("tungsten.core.tokenizer")
local space = tk.space

local M = {}

local function create_quantity_node(value, unit)
	return {
		type = "quantity",
		value = value,
		unit = unit,
		children = { value },
	}
end

local function create_num_node(value)
	return value
end

local LBrace = P("{") * space
local RBrace = space * P("}")

local ExprArg = LBrace * V("Expression") * RBrace

local UnitContent = Cs((P("\\") ^ -1) * (tk.variable + P(1) - RBrace) ^ 1)
local UnitArg = LBrace * UnitContent * RBrace

M.Qty = (P("\\qty") * space * Cg(ExprArg, "val") * space * Cg(UnitArg, "unit"))
	/ function(c)
		return create_quantity_node(c.val, c.unit)
	end

M.Ang = (P("\\ang") * space * Cg(ExprArg, "val")) / function(c)
	return create_quantity_node(c.val, "Degree")
end

M.Num = (P("\\num") * space * ExprArg) / create_num_node

return M
