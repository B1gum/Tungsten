-- lua/tungsten/backends/wolfram/wolfram_error.lua
-- Helper for parsing WolframScript error messages

local M = {}

local function concat_output(output_lines)
	if type(output_lines) == "table" then
		return table.concat(output_lines, "\n")
	elseif type(output_lines) == "string" then
		return output_lines
	end
	return ""
end

function M.parse_wolfram_error(output_lines)
	local output = concat_output(output_lines)
	if output == "" then
		return nil
	end

	for line in output:gmatch("[^\n]+") do
		local name, msg = line:match("%s*(%S+::%S+):%s*(.-)%s*>?%s*$")
		if name and msg then
			msg = msg:gsub("%s*>>%s*$", "")
			return string.format("%s: %s", name, msg)
		end
	end

	local name, rest = output:match("Message%[%s*(%S+::%S+)%s*,%s*(.-)%s*%]")
	if name then
		rest = rest:gsub('^"', ""):gsub('"$', "")
		return string.format("%s: %s", name, rest)
	end

	return nil
end

return M
