-- lua/tungsten/backends/python/python_error.lua
-- Simple error parser for Python output

local M = {}

function M.parse_python_error(output)
	if type(output) ~= "string" then
		return nil
	end
	if output:match("Traceback%:") then
		return output
	end
	return nil
end

return M
