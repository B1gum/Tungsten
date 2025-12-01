local M = {}

M.handlers = {
	quantity = function(node, recur_render)
		local val = recur_render(node.value)
		local unit = node.unit

		if unit == "Degree" then
			return string.format("(%s) * Degree", val)
		end

		return string.format("(%s) * %s", val, unit)
	end,
}

return M
