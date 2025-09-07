local M = {}

function M.find_math_block_end(bufnr, start_line)
	bufnr = bufnr or 0
	start_line = start_line or 0
	local lines = vim.api.nvim_buf_get_lines(bufnr, start_line + 1, -1, false)
	for i, line in ipairs(lines) do
		if line:find("%s%s") or line:find("\\%]") then
			return start_line + i
		end
	end
	return start_line
end

return M
