local M = {}

M.attributes = {
	["+"] = { prec = 1, assoc = "L" },
	["-"] = { prec = 1, assoc = "L" },
	["*"] = { prec = 2, assoc = "L" },
	["/"] = { prec = 2, assoc = "L" },
	["^"] = { prec = 3, assoc = "R" },
	["=="] = { prec = 0, assoc = "N" },
	["="] = { prec = 0, assoc = "N" },
	["\\cdot"] = { prec = 2, assoc = "L" },
	["\\times"] = { prec = 2, assoc = "L" },
}

local function copy_attributes(attrs)
	return { prec = attrs.prec, assoc = attrs.assoc }
end

function M.with_symbols(symbol_key, symbol_map)
	local extended = {}

	for operator, attrs in pairs(M.attributes) do
		local attr_copy = copy_attributes(attrs)
		attr_copy[symbol_key] = (symbol_map and symbol_map[operator]) or operator
		extended[operator] = attr_copy
	end

	return extended
end

return M
