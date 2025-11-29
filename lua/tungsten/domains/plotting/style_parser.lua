local M = {}

function M.parse(tokens)
	local res = {}
	if type(tokens) == "string" then
		tokens = vim.split(tokens, " ", { trimempty = true })
	end
	if type(tokens) ~= "table" then
		return res
	end
	for _, tok in ipairs(tokens) do
		local key, val = tok:match("^%s*(%w+)%s*=%s*(.-)%s*$")
		if key and val then
			val = val:gsub("^['\"]", ""):gsub("['\"]$", "")
			local num = tonumber(val)
			res[key] = num or val
		end
	end
	return res
end

return M
