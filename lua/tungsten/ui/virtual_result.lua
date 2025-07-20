local M = {}

local state = require("tungsten.state")

local extmarks = {}

function M.clear()
	local bufnr = vim.api.nvim_get_current_buf()
	for _, id in ipairs(extmarks) do
		pcall(vim.api.nvim_buf_del_extmark, bufnr, state.ns, id)
	end
	extmarks = {}
end

function M.show(text, start_line)
	text = text or ""
	start_line = start_line or (vim.api.nvim_win_get_cursor(0)[1] - 1)
	local bufnr = vim.api.nvim_get_current_buf()

	M.clear()

	local lines = vim.split(text, "\n")
	for i, line in ipairs(lines) do
		local row = start_line + i - 1
		local id = vim.api.nvim_buf_set_extmark(bufnr, state.ns, row, -1, {
			virt_text = { { line } },
			virt_text_pos = "eol",
		})
		table.insert(extmarks, id)
	end
end

return M
