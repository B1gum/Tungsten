local M = {}

function M.show(text)
	text = text or ""
	local lines = vim.split(text, "\n")
	local width = 0
	for _, l in ipairs(lines) do
		if #l > width then
			width = #l
		end
	end
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	local opts = {
		relative = "cursor",
		row = 1,
		col = 1,
		width = width,
		height = #lines,
		style = "minimal",
		border = "single",
	}
	vim.api.nvim_open_win(buf, false, opts)
end

return M
