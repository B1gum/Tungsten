-- tungsten/util/commands.lua
local M = {}

local selection = require("tungsten.util.selection")
local parser = require("tungsten.core.parser")

function M.parse_selected_latex(expected_desc)
	local text = selection.get_visual_selection()
	if not text or text == "" then
		return nil, nil, "No " .. expected_desc .. " selected."
	end

	local ok, parsed, err_msg = pcall(parser.parse, text)
	if not ok or not parsed then
		return nil, nil, err_msg or tostring(parsed)
	end
	if not parsed.series or #parsed.series ~= 1 then
		return nil, text, "Selection must contain a single expression"
	end

	return parsed.series[1], text, nil
end

return M
