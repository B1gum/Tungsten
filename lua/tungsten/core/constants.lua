-- tungsten/core/constants.lua
-- Shared table of well-known mathematical constants and utility helpers

local constants = {
	e = {
		python = "E",
		wolfram = "E",
	},
}

local M = {}

---Returns normalized constant metadata for a given name.
---@param name string|nil
---@return table|nil
function M.get(name)
	if type(name) ~= "string" then
		return nil
	end
	return constants[name:lower()]
end

function M.is_constant(name)
	return M.get(name) ~= nil
end

return M
