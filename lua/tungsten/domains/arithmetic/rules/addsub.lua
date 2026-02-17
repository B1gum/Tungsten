local lpeg = vim.lpeg
local Cf, S, Ct, C, V = lpeg.Cf, lpeg.S, lpeg.Ct, lpeg.C, lpeg.V
local space = require("tungsten.core.tokenizer").space
local create_binary_operation_node = require("tungsten.core.ast").create_binary_operation_node

local AddSub = Cf(V("MulDiv") * (space * Ct(C(S("+-")) * space * V("MulDiv"))) ^ 0, function(acc, pair)
	return create_binary_operation_node(pair[1], acc, pair[2])
end)

return AddSub
