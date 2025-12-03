-- lua/tungsten/backends/wolfram/domains/units.lua
local M = {}

M.handlers = {}

local function render_unit(node)
	if not node then
		return ""
	end

	if node.type == "unit_component" then
		return node.name:gsub("^\\", "")
	elseif node.type == "superscript" then
		return render_unit(node.base) .. "^" .. render_unit(node.exponent)
	elseif node.type == "binary" then
		local left = render_unit(node.left)
		local right = render_unit(node.right)

		if node.operator == "/" then
			return left .. "/" .. right
		else
			return left .. " " .. right
		end
	elseif node.type == "number" then
		return tostring(node.value)
	end

	return ""
end

M.handlers.quantity = function(node, render_fn)
	local val = render_fn(node.value)
	local unit_str = render_unit(node.unit)

	return string.format('Quantity[%s, "%s"]', val, unit_str)
end

M.handlers.angle = function(node, render_fn)
	return string.format('Quantity[%s, "AngularDegrees"]', render_fn(node.value))
end

M.handlers.num_cmd = function(node, render_fn)
	return render_fn(node.value)
end

return M
