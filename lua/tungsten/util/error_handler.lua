local M = {
	E_TEX_ROOT_NOT_FOUND = "E_TEX_ROOT_NOT_FOUND",
	E_BACKEND_UNAVAILABLE = "E_BACKEND_UNAVAILABLE",
	E_UNSUPPORTED_DIM = "E_UNSUPPORTED_DIM",
	E_UNSUPPORTED_FORM = "E_UNSUPPORTED_FORM",
	E_MIXED_COORD_SYS = "E_MIXED_COORD_SYS",
	E_BAD_OPTS = "E_BAD_OPTS",
	E_NO_CONTOUR = "E_NO_CONTOUR",
	E_NO_ISOSURFACE = "E_NO_ISOSURFACE",
	E_VIEWER_FAILED = "E_VIEWER_FAILED",
	E_CANCELLED = "E_CANCELLED",
	E_BACKEND_CRASH = "E_BACKEND_CRASH",
	E_TIMEOUT = "E_TIMEOUT",
	E_INVALID_CLASSIFICATION = "E_INVALID_CLASSIFICATION",
	E_NO_PLOTTABLE_SERIES = "E_NO_PLOTTABLE_SERIES",
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

function M.notify_error(context, error_code, err_pos, input, message_suffix)
	local location_suffix = ""
	if err_pos and input then
		location_suffix = " (" .. M.format_line_col(input, err_pos) .. ")"
	end
	local human_message = ""
	if message_suffix and tostring(message_suffix) ~= "" then
		human_message = ": " .. tostring(message_suffix)
	end
	local message =
		string.format("Tungsten[%s] %s%s%s", tostring(context), tostring(error_code), location_suffix, human_message)
	if vim and vim.notify then
		vim.schedule(function()
			vim.notify(message, vim.log.levels.ERROR)
		end)
	else
		print(message)
	end
end

return M
