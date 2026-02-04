local config = require("tungsten.config")
local spinner = require("tungsten.domains.plotting.job_manager.spinner")

local M = {}

local function resolve_enabled(opts)
	if type(opts) == "boolean" then
		return opts
	end
	if type(opts) == "table" and opts.enabled ~= nil then
		return opts.enabled
	end
	if type(config.job_spinner) == "boolean" then
		return config.job_spinner
	end
	if type(config.job_spinner) == "table" and config.job_spinner.enabled ~= nil then
		return config.job_spinner.enabled
	end
	return true
end

local function clamp_row(bufnr, row)
	local line_count = vim.api.nvim_buf_line_count(bufnr)
	if line_count < 1 then
		line_count = 1
	end
	if row < 0 then
		return 0
	end
	if row >= line_count then
		return line_count - 1
	end
	return row
end

local function clamp_col(bufnr, row, col)
	local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
	local max_col = #line
	if col < 0 then
		return 0
	end
	if col > max_col then
		return max_col
	end
	return col
end

local function resolve_anchor(opts)
	local bufnr, row, col
	if type(opts) == "table" then
		if opts.bufnr ~= nil and opts.row ~= nil and opts.col ~= nil then
			bufnr = opts.bufnr
			row = opts.row
			col = opts.col
		end
	end

	if not bufnr then
		bufnr = vim.api.nvim_get_current_buf()
		local cursor = vim.api.nvim_win_get_cursor(0)
		row = cursor[1] - 1
		col = cursor[2]
	end

	if not vim.api.nvim_buf_is_valid(bufnr) then
		return nil
	end

	row = clamp_row(bufnr, row)
	col = clamp_col(bufnr, row, col)

	return bufnr, row, col
end

function M.start(opts)
	if not resolve_enabled(opts) then
		return nil
	end

	local ok, bufnr, row, col = pcall(resolve_anchor, opts)
	if not ok or not bufnr then
		return nil
	end

	local extmark_id, timer, spinner_ns = spinner.start_spinner(bufnr, row, col)
	return {
		bufnr = bufnr,
		extmark_id = extmark_id,
		timer = timer,
		spinner_ns = spinner_ns,
	}
end

function M.stop(handle)
	if not handle then
		return
	end

	local function do_stop()
		if handle.timer then
			handle.timer:stop()
			handle.timer:close()
			handle.timer = nil
		end

		if handle.extmark_id and handle.spinner_ns and handle.bufnr then
			pcall(vim.api.nvim_buf_del_extmark, handle.bufnr, handle.spinner_ns, handle.extmark_id)
		end
	end

	if vim.in_fast_event() then
		vim.schedule(do_stop)
	else
		do_stop()
	end
end

return M
