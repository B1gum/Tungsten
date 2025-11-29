local selection = require("tungsten.util.selection")

local M = {}

function M.get_selection_range()
	local bufnr = vim.api.nvim_get_current_buf()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")

	if start_pos[1] == 0 or end_pos[1] == 0 then
		return bufnr, 0, 0, 0, 0
	end

	if start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
		start_pos, end_pos = end_pos, start_pos
	end

	local start_line = math.max(start_pos[2] - 1, 0)
	local end_line = math.max(end_pos[2] - 1, 0)
	local start_col = math.max(start_pos[3] - 1, 0)
	local end_col = math.max(end_pos[3], 0)

	local line = vim.api.nvim_buf_get_lines(bufnr, end_line, end_line + 1, false)[1] or ""
	if end_col > #line then
		end_col = #line
	end

	local mode = vim.fn.mode(1)
	if mode == "V" then
		start_col = 0
		end_col = 0
		end_line = end_line + 1
	end

	return bufnr, start_line, start_col, end_line, end_col
end

function M.get_trimmed_visual_selection()
	local text = selection.get_visual_selection()
	if type(text) ~= "string" then
		text = ""
	end

	return text:gsub("^%s+", ""):gsub("%s+$", "")
end

return M
