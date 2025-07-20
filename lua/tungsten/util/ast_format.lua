local M = {}

local function collect_children(node)
	local children = {}
	for i = 1, #node do
		children[#children + 1] = { label = "[" .. i .. "]", value = node[i] }
	end
	for k, v in pairs(node) do
		if k ~= "type" and (type(k) ~= "number" or k > #node) then
			children[#children + 1] = { label = tostring(k), value = v }
		end
	end
	return children
end

local function format(node, indent, prefix)
	indent = indent or ""
	prefix = prefix or ""
	if type(node) ~= "table" then
		return indent .. prefix .. tostring(node)
	end
	local lines = {}
	local node_name = node.type or "<table>"
	lines[#lines + 1] = indent .. prefix .. node_name
	local children = collect_children(node)
	for i, child in ipairs(children) do
		local last = i == #children
		local child_prefix = (last and "└─" or "├─") .. child.label .. ": "
		local next_indent = indent .. (last and "  " or "│ ")
		lines[#lines + 1] = format(child.value, next_indent, child_prefix)
	end
	return table.concat(lines, "\n")
end

function M.format(ast)
	return format(ast)
end

return M
