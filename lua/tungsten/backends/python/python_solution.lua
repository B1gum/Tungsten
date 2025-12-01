-- lua/tungsten/backends/python/python_solution.lua
-- Helper for parsing SymPy solve output

local M = {}

local function trim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.parse_python_solution(output_lines, vars, _)
	local output = ""
	if type(output_lines) == "table" then
		output = table.concat(output_lines, "\n")
	elseif type(output_lines) == "string" then
		output = output_lines
	end

	if output == "" then
		return { ok = false, reason = "No solution" }
	end

	local map = {}
	for var, val in output:gmatch("(%w+)%s*:%s*([^,%}%]]+)") do
		map[trim(var)] = trim(val)
	end

	if next(map) then
		local parts = {}
		for _, name in ipairs(vars) do
			if map[name] then
				table.insert(parts, name .. " = " .. map[name])
			else
				table.insert(parts, name .. " = (Not explicitly solved)")
			end
		end
		return { ok = true, formatted = table.concat(parts, ", ") }
	end

	return { ok = true, formatted = output }
end

return M
