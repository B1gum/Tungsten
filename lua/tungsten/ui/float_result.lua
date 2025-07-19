local M = {}

local current_win

function M.close()
	if current_win and vim.api.nvim_win_is_valid(current_win) then
		vim.api.nvim_win_close(current_win, true)
	end
	current_win = nil
end

function M.show(text)
	M.close()

	text = text or ""
	local lines = vim.split(text, "\n")
	local width = 0
	for _, l in ipairs(lines) do
		if #l > width then
			width = #l
		end
	end
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
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
	current_win = vim.api.nvim_open_win(buf, false, opts)
	vim.keymap.set("n", "<Esc>", M.close, { buffer = buf, nowait = true, silent = true })
end

return M
