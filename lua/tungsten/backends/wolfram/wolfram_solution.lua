-- lua/tungsten/backends/wolfram/wolfram_solution.lua

local string_util = require("tungsten.util.string")
local error_parser = require("tungsten.backends.wolfram.wolfram_error")

local M = {}

local unit_map = {
	["Meters"] = "\\meter",
	["Seconds"] = "\\second",
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

local prefixed_unit_macros = {
	Deca = "\\deca",
	Yotta = "\\yotta",
	Zetta = "\\zetta",
	Exa = "\\exa",
	Peta = "\\peta",
	Tera = "\\tera",
	Giga = "\\giga",
	Mega = "\\mega",
	Kilo = "\\kilo",
	Hecto = "\\hecto",
	Deci = "\\deci",
	Centi = "\\centi",
	Milli = "\\milli",
	Micro = "\\micro",
	Nano = "\\nano",
	Pico = "\\pico",
	Femto = "\\femto",
	Atto = "\\atto",
	Zepto = "\\zepto",
	Yocto = "\\yocto",
}

local tex_unit_prefixes = {
	"da",
	"Y",
	"Z",
	"E",
	"P",
	"T",
	"G",
	"M",
	"k",
	"h",
	"d",
	"c",
	"m",
	"u",
	"μ",
	"n",
	"p",
	"f",
	"a",
	"z",
	"y",
}

local tex_unit_base_macros = {
	m = "\\meter",
	s = "\\second",
	A = "\\ampere",
	K = "\\kelvin",
	mol = "\\mole",
	cd = "\\candela",
	Pa = "\\pascal",
	N = "\\newton",
	J = "\\joule",
	W = "\\watt",
	V = "\\volt",
	ohm = "\\ohm",
	Hz = "\\hertz",
	C = "\\coulomb",
	F = "\\farad",
	T = "\\tesla",
	Wb = "\\weber",
	H = "\\henry",
	lm = "\\lumen",
	lx = "\\lux",
	Bq = "\\becquerel",
	Gy = "\\gray",
	Sv = "\\sievert",
	kat = "\\katal",
	rad = "\\radian",
	deg = "\\degree",
}

table.sort(tex_unit_prefixes, function(a, b)
	return #a > #b
end)

local prefixed_unit_names = {}
for prefix_name, prefix_macro in pairs(prefixed_unit_macros) do
	table.insert(prefixed_unit_names, { name = prefix_name, macro = prefix_macro })
end

table.sort(prefixed_unit_names, function(a, b)
	return #a.name > #b.name
end)

local function normalize_prefixed_unit(unit_name)
	for _, prefix in ipairs(prefixed_unit_names) do
		if unit_name:sub(1, #prefix.name) == prefix.name then
			local base_name = unit_name:sub(#prefix.name + 1)
			local base_macro = unit_map[base_name]
			if not base_macro and base_name ~= "" then
				local capitalized = base_name:gsub("^%l", string.upper)
				base_macro = unit_map[capitalized]
			end
			if base_macro then
				return prefix.macro .. base_macro
			end
		end
	end
	return nil
end

local function normalize_texform_unit(unit_text)
	local trimmed = unit_text:gsub("%s+", "")
	if trimmed == "" then
		return nil
	end

	for _, prefix in ipairs(tex_unit_prefixes) do
		if trimmed:sub(1, #prefix) == prefix then
			local base = trimmed:sub(#prefix + 1)
			if base ~= "" and tex_unit_base_macros[base] then
				return "\\" .. prefix .. base
			end
		end
	end

	return tex_unit_base_macros[trimmed]
end

local function normalize_unit_expression(unit_expr)
	local sanitized = unit_expr:gsub('"', "")

	local direct_match = unit_map[sanitized]
	if direct_match then
		return direct_match
	end

	local replaced_units = sanitized:gsub("%a+", function(unit)
		return normalize_prefixed_unit(unit) or unit_map[unit] or unit
	end)

	return replaced_units:gsub("%s*%*%s*", "."):gsub("%s*/%s*", "\\per"):gsub("%s+", "."):gsub("%^", "^")
end

function M.format_quantities(str)
	if not str then
		return ""
	end

	local formatted = str:gsub("Quantity%[([^,]+),%s*(.-)%]", function(val, unit_expr)
		local clean_unit = unit_expr:gsub('"', "")
		if clean_unit == "AngularDegrees" then
			return string.format("\\ang{%s}", val)
		end

		local latex_unit = normalize_unit_expression(unit_expr)

		return string.format("\\qty{%s}{%s}", val, latex_unit)
	end)

	return formatted:gsub("([%+%-]?[%d%.]+)%s*\\text%{([^}]+)%}", function(val, unit_text)
		local normalized = normalize_texform_unit(unit_text)
		if normalized then
			return string.format("\\qty{%s}{%s}", val, normalized)
		end
		return string.format("%s\\text{%s}", val, unit_text)
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

	output = output:gsub("\\theta", "u")

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
