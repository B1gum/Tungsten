-- util/selection.lua
-- Module to retrieve the visually selected text-input
-------------------------------------------------------------------------------------------

local M = {}
function M.get_visual_selection()
	local bufnr = 0
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")

	local start_line_api = start_pos[2] - 1
	local start_col_api = start_pos[3] - 1
	local end_line_api = end_pos[2] - 1
	local end_col_api = end_pos[3]

	if start_line_api < 0 or start_col_api < 0 then
		return ""
	end

	local lines_table = vim.api.nvim_buf_get_text(bufnr, start_line_api, start_col_api, end_line_api, end_col_api, {})
	return table.concat(lines_table, "\n")
end
return M
