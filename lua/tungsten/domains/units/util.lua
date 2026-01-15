local M = {}

function M.render_unit(node)
	if not node then
		return ""
	end

	if node.type == "unit_component" then
		return node.name:gsub("^\\", "")
	elseif node.type == "superscript" then
		return M.render_unit(node.base) .. "^" .. M.render_unit(node.exponent)
	elseif node.type == "binary" then
		local left = M.render_unit(node.left)
		local right = M.render_unit(node.right)

		if node.operator == "/" then
			return left .. "/" .. right
		end
		return left .. " " .. right
	elseif node.type == "number" then
		return tostring(node.value)
	end

	return ""
end

return M
