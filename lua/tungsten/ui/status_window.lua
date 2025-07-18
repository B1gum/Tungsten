local engine = require("tungsten.core.engine")

local M = {}

function M.open(summary)
	summary = summary or engine.get_active_jobs_summary()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	local lines = vim.split(summary, "\n")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local width = 0
	for _, line in ipairs(lines) do
		width = math.max(width, #line)
	end
	width = math.max(width, 20)
	local height = #lines

	local opts = {
		relative = "editor",
		style = "minimal",
		border = "rounded",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
	}

	local win = vim.api.nvim_open_win(buf, true, opts)
	return { win_id = win, buf_id = buf }
end

return M
