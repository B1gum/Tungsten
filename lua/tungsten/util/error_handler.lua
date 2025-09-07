local M = {
	E_BACKEND_UNAVAILABLE = "E_BACKEND_UNAVAILABLE",
	E_UNSUPPORTED_FORM = "E_UNSUPPORTED_FORM",
	E_TIMEOUT = "E_TIMEOUT",
	E_BACKEND_CRASH = "E_BACKEND_CRASH",
}

local function calc_line_col(input, pos)
	if type(input) ~= "string" or type(pos) ~= "number" then
		return 1, pos or 1
	end
	local line, col = 1, 1
	for i = 1, pos - 1 do
		local c = input:sub(i, i)
		if c == "\n" then
			line = line + 1
			col = 1
		else
			col = col + 1
		end
	end
	return line, col
end

function M.format_line_col(input, pos)
	local line, col = calc_line_col(input, pos)
	return string.format("line %d, column %d", line, col)
end

function M.notify_error(context, error_code, err_pos, input)
	local location_suffix = ""
	if err_pos and input then
		location_suffix = " (" .. M.format_line_col(input, err_pos) .. ")"
	end
	local message = string.format("Tungsten[%s] %s%s", tostring(context), tostring(error_code), location_suffix)
	if vim and vim.notify then
		vim.schedule(function()
			vim.notify(message, vim.log.levels.ERROR)
		end)
	else
		print(message)
	end
end

return M
