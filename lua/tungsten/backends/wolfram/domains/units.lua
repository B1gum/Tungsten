local M = {}

M.handlers = {
	quantity = function(node, recur_render)
		local val = recur_render(node.value)
		local unit = node.unit

		if unit == "Degree" then
			return string.format('Quantity[%s, "AngularDegrees"]', val)
		end

		return string.format('Quantity[%s, "%s"]', val, unit)
	end,
}

return M
