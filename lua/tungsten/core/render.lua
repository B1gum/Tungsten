-- tungsten/core/render.lua
-- Traverses an AST and converts it into a string representation
-- using table of handlers
--------------------------------------------------------------------
local M = {}

local function _walk(node, handlers)
	if type(node) ~= "table" then
		return tostring(node)
	end

	local tag = node.type
	if not tag then
		error("render.walk: node missing tag/type field")
	end

	local h = handlers[tag]
	if not h then
		return {
			error = true,
			message = 'render.walk: no handler for tag "' .. tostring(tag) .. '"',
			node_type = tag,
		}
	end

	local ok, result_or_error = pcall(h, node, function(child)
		local res = _walk(child, handlers)
		if type(res) == "table" and res.error then
			return res
		end
		return res
	end)

	if not ok then
		return {
			error = true,
			message = "Error in handler for tag '" .. tostring(tag) .. "': " .. tostring(result_or_error),
			node_type = tag,
			original_error = result_or_error,
		}
	end

	if type(result_or_error) == "table" and result_or_error.error then
		return result_or_error
	end

	return result_or_error
end

function M.render(ast, handlers)
	assert(type(handlers) == "table", "render.render: handlers must be a table")
	local result = _walk(ast, handlers)

	return result
end

return M
