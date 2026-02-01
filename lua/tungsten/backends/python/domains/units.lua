local M = {}

M.handlers = {}

local function render_unit(node, render_fn)
	if not node then
		return ""
	end

	if node.type == "unit_component" then
		local unit_name = node.name:gsub("^\\", "")
		return ("u.%s"):format(unit_name)
	elseif node.type == "superscript" then
		local base = render_unit(node.base, render_fn)
		local exponent = render_fn(node.exponent)
		return ("(%s) ** (%s)"):format(base, exponent)
	elseif node.type == "binary" then
		local left = render_unit(node.left, render_fn)
		local right = render_unit(node.right, render_fn)
		local op = node.operator == "/" and "/" or "*"
		return ("(%s) %s (%s)"):format(left, op, right)
	elseif node.type == "number" then
		return tostring(node.value)
	end

	return ""
end

M.handlers.quantity = function(node, render_fn)
	local val = render_fn(node.value)
	local unit = render_unit(node.unit, render_fn)

	return string.format("(%s) * (%s)", val, unit)
end

M.handlers.angle = function(node, render_fn)
	return string.format("(%s) * u.deg", render_fn(node.value))
end

M.handlers.num_cmd = function(node, render_fn)
	return render_fn(node.value)
end

return M
