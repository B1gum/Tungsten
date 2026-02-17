local lpeg = vim.lpeg
local P, C = lpeg.P, lpeg.C

local tk = require("tungsten.core.tokenizer")
local space = tk.space
local ast = require("tungsten.core.ast")

local StandardMulDiv = require("tungsten.domains.arithmetic.rules.muldiv")

local operator = C(P("\\ast"))

local function fold_convolution(...)
	local args = { ... }
	local left = args[1]

	for i = 2, #args, 2 do
		local op_str = args[i]
		local right = args[i + 1]

		if op_str == "\\ast" and right then
			left = ast.create_convolution_node(left, right)
		end
	end

	return left
end

local ConvolutionPattern = (StandardMulDiv * (space * operator * space * StandardMulDiv) ^ 0) / fold_convolution

return ConvolutionPattern
