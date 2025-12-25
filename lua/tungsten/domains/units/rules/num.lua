local lpeg = require("lpeglabel")
local P = lpeg.P
local ast = require("tungsten.core.ast")
local tk = require("tungsten.core.tokenizer")

local NumCmd = P("\\num")
local LBrace = tk.lbrace
local RBrace = tk.rbrace

local function parse_si_num(str)
	local clean_str = str:gsub(",", ".")
	return tonumber(clean_str)
end

local Content = (
	lpeg.R("09") ^ 1
	* (lpeg.S(".,") * lpeg.R("09") ^ 1) ^ -1
	* (lpeg.S("eE") * lpeg.S("+-") ^ -1 * lpeg.R("09") ^ 1) ^ -1
)
	/ parse_si_num
	/ ast.create_number_node

local NumRule = NumCmd * tk.space * LBrace * tk.space * Content * tk.space * RBrace / ast.create_num_node

return NumRule
