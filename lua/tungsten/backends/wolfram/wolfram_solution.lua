-- lua/tungsten/backends/wolfram/wolfram_solution.lua
-- Helper for parsing WolframScript Solve[] output and formatting Quantities

local string_util = require("tungsten.util.string")
local error_parser = require("tungsten.backends.wolfram.wolfram_error")

local M = {}

local unit_map = {
	["Meters"] = "\\meter",
	["Seconds"] = "\\seconds",
	["Kilograms"] = "\\kilogram",
	["Newtons"] = "\\newton",
	["Joules"] = "\\joule",
	["Watts"] = "\\watt",
	["Pascals"] = "\\pascal",
	["Amperes"] = "\\ampere",
	["Volts"] = "\\volt",
	["Ohms"] = "\\ohm",
	["Degrees"] = "\\degree",
	["Radians"] = "\\radian",
	["Hertz"] = "\\hertz",
	["Coulombs"] = "\\coulomb",
	["Becquerels"] = "\\becquerel",
	["Farads"] = "\\farad",
	["Grays"] = "\\gray",
	["Henrys"] = "\\henry",
	["Lumens"] = "\\lumen",
	["Katals"] = "\\katal",
	["lux"] = "\\lux",
	["Siemens"] = "\\siemens",
	["Sieverts"] = "\\sievert",
	["Teslas"] = "\\tesla",
	["Webers"] = "\\weber",
}

local function normalize_unit_expression(unit_expr)
	local sanitized = unit_expr:gsub('"', "")

	local direct_match = unit_map[sanitized]
	if direct_match then
		return direct_match
	end

	local replaced_units = sanitized:gsub("%a+", function(unit)
		return unit_map[unit] or unit
	end)

	return replaced_units:gsub("%s*%*%s*", "."):gsub("%s*/%s*", "\\\\per"):gsub("%s+", "."):gsub("%^", "^")
end

function M.format_quantities(str)
	if not str then
		return ""
	end

	return str:gsub("Quantity%[([^,]+),%s*(.-)%]", function(val, unit_expr)
		local latex_unit = normalize_unit_expression(unit_expr)

		return string.format("\\qty{%s}{%s}", val, latex_unit)
	end)
end

local function escape_pattern(text)
	return text:gsub("(%W)", "%%%1")
end

function M.parse_wolfram_solution(output_lines, vars, is_system)
	local output = ""
	if type(output_lines) == "table" then
		output = table.concat(output_lines, "\n")
	elseif type(output_lines) == "string" then
		output = output_lines
	end

	if output == "" then
		return { ok = false, reason = "No solution" }
	end

	local err = error_parser.parse_wolfram_error(output)
	if err then
		return { ok = false, reason = err }
	end

	local raw = output
	local temp = raw:match("^%s*{{(.*)}}%s*$") or raw:match("^%s*{(.*)}%s*$") or raw

	local map = {}
	for pair in temp:gmatch("([^,{}]+%s*->%s*[^,{}]+)") do
		local var, val = pair:match("(.+)%s*->%s*(.+)")
		if var and val then
			map[string_util.trim(var)] = string_util.trim(val)
		end
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
		return { ok = true, formatted = M.format_quantities(table.concat(parts, ", ")) }
	end

	if not is_system and #vars == 1 then
		local var = escape_pattern(vars[1])
		local single = raw:match("{{%s*" .. var .. "%s*->%s*(.-)%s*}}") or raw:match("{%s*" .. var .. "%s*->%s*(.-)%s*}")
		if single then
			return { ok = true, formatted = M.format_quantities(vars[1] .. " = " .. string_util.trim(single)) }
		end
	end

	return { ok = true, formatted = M.format_quantities(raw) }
end

return M
