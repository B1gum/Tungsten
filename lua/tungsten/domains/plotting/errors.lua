local error_handler = require("tungsten.util.error_handler")

local M = {}

function M.normalize_job_error(err)
	local code = err and err.code
	local cancelled = err and err.cancelled
	local backend_error_code = err and err.backend_error_code

	local message = ""
	if err and err.message ~= nil then
		message = tostring(err.message)
	end

	local message_suffix
	local lower_msg = message ~= "" and message:lower() or nil

	if cancelled or code == -1 then
		return error_handler.E_CANCELLED, nil, nil
	elseif code == 127 then
		message_suffix = message ~= "" and message or nil
		return error_handler.E_BACKEND_UNAVAILABLE, message_suffix, nil
	elseif code == 124 or (lower_msg and lower_msg:find("timeout")) then
		message_suffix = message ~= "" and message or nil
		return error_handler.E_TIMEOUT, message_suffix, nil
	elseif backend_error_code then
		message_suffix = message ~= "" and message or nil
		return nil, message_suffix, backend_error_code
	else
		message_suffix = (message ~= "") and message or nil
		return error_handler.E_BACKEND_CRASH, message_suffix, nil
	end
end

return M
