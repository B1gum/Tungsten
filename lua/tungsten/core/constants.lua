-- tungsten/core/constants.lua
-- Shared table of well-known mathematical constants and utility helpers

local constants = {
	e = {
		python = "E",
		wolfram = "E",
	},
	infinity = {
		python = "sp.oo",
		wolfram = "Infinity",
	},
	pi = {
		python = "sp.pi",
		wolfram = "Pi",
	},
}

local M = {}

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
