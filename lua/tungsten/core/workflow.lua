local selection = require("tungsten.util.selection")
local event_bus = require("tungsten.event_bus")
local error_handler = require("tungsten.util.error_handler")

local M = {}

function M.run(definition)
	local ast, text, parse_err = definition.input_handler()

	if parse_err then
		error_handler.notify_error(definition.description or "", parse_err)
		return
	end
	if not ast then
		return
	end

	local _, start_mark, end_mark, mode = selection.create_selection_extmarks()

	local args = { ast, text }
	if definition.prepare_args then
		args = definition.prepare_args(ast, text)
	end

	local function on_complete(result, err)
		if err then
			error_handler.notify_error(definition.description or "", err)
			return
		end
		if result == nil or result == "" then
			return
		end
		event_bus.emit("result_ready", {
			result = result,
			start_mark = start_mark,
			end_mark = end_mark,
			selection_text = text,
			mode = mode,
			separator = definition.separator,
		})
	end

	table.insert(args, on_complete)

	local ok, err = pcall(definition.task_handler, unpack(args))
	if not ok then
		error_handler.notify_error(definition.description or "", err)
	end
end

return M
