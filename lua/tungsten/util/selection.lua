-- util/selection.lua
-- Module to retrieve the visually selected text-input

local state = require("tungsten.state")

local M = {}

function M.create_selection_extmarks()
	local bufnr = vim.api.nvim_get_current_buf()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")
	local mode = vim.fn.mode(1)

	local start_line = start_pos[2] - 1
	local end_line = end_pos[2] - 1
	local start_col = start_pos[3] - 1
	local end_col = end_pos[3]

	local line_len = #(vim.api.nvim_buf_get_lines(bufnr, end_line, end_line + 1, false)[1] or "")
	if end_col > line_len then
		end_col = line_len
	end

	if mode == "V" then
		start_col = 0
		end_col = 0
		end_line = end_line + 1
	end

	local start_id = vim.api.nvim_buf_set_extmark(bufnr, state.ns, start_line, start_col, { right_gravity = false })
	local end_id = vim.api.nvim_buf_set_extmark(bufnr, state.ns, end_line, end_col, { right_gravity = true })

	return bufnr, start_id, end_id, mode
end

function M.get_visual_selection()
	local bufnr = 0
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")

	if start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
		return ""
	end

	local start_line_api = start_pos[2] - 1
	local start_col_api = start_pos[3] - 1
	local end_line_api = end_pos[2] - 1
	local end_col_api = end_pos[3]

	if start_line_api < 0 or start_col_api < 0 or end_line_api < 0 or end_col_api < 0 then
		return ""
	end

	local lines_table = vim.api.nvim_buf_get_text(bufnr, start_line_api, start_col_api, end_line_api, end_col_api, {})
	return table.concat(lines_table, "\n")
end
return M
