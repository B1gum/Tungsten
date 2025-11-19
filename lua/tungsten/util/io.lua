local plotting_io = require("tungsten.util.plotting_io")

local M = {}

function M.find_math_block_end(bufnr, start_line)
	return plotting_io.find_math_block_end(bufnr, start_line)
end

return M
