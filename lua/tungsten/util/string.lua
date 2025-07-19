-- tungsten/util/string.lua
-- String utility functions
-------------------------------------------
local M = {}

function M.trim(str)
	if type(str) ~= "string" then
		return str
	end
  return vim.trim(str)
end

return M
