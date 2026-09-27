local lpeg = vim.lpeg
local P, S = lpeg.P, lpeg.S
local ast = require("tungsten.core.ast")
local tk = require("tungsten.core.tokenizer")

local AngCmd = P("\\ang")

local LBrace = tk.lbrace
local RBrace = tk.rbrace

local function parse_si_num(str)
	local clean_str = str:gsub(",", ".")
	return tonumber(clean_str)
end

local Content = (
	S("+-") ^ -1
	* lpeg.R("09") ^ 1
	* (S(".,") * lpeg.R("09") ^ 1) ^ -1
	* (S("eE") * S("+-") ^ -1 * lpeg.R("09") ^ 1) ^ -1
)
	/ parse_si_num
	/ ast.create_number_node

local AngRule = AngCmd * tk.space * LBrace * tk.space * Content * tk.space * RBrace / ast.create_angle_node

return AngRule
