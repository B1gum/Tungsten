local M = {}

function M.has_units(node)
	if type(node) ~= "table" then
		return false
	end
	if node.type == "quantity" or node.type == "unit_component" or node.type == "angle" then
		return true
	end
	for _, v in pairs(node) do
		if type(v) == "table" and M.has_units(v) then
			return true
		end
	end
	return false
end

function M.is_unit_convert_call(node)
	if type(node) ~= "table" then
		return false
	end
	if node.type ~= "function_call" then
		return false
	end
	local name_node = node.name_node
	return name_node and name_node.name == "UnitConvert"
end

return M
