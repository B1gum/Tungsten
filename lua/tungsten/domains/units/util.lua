local M = {}

local wolfram_unit_prefixes = {
	{ symbol = "da", name = "Deca" },
	{ symbol = "Y", name = "Yotta" },
	{ symbol = "Z", name = "Zetta" },
	{ symbol = "E", name = "Exa" },
	{ symbol = "P", name = "Peta" },
	{ symbol = "T", name = "Tera" },
	{ symbol = "G", name = "Giga" },
	{ symbol = "M", name = "Mega" },
	{ symbol = "k", name = "Kilo" },
	{ symbol = "h", name = "Hecto" },
	{ symbol = "d", name = "Deci" },
	{ symbol = "c", name = "Centi" },
	{ symbol = "m", name = "Milli" },
	{ symbol = "u", name = "Micro" },
	{ symbol = "μ", name = "Micro" },
	{ symbol = "n", name = "Nano" },
	{ symbol = "p", name = "Pico" },
	{ symbol = "f", name = "Femto" },
	{ symbol = "a", name = "Atto" },
	{ symbol = "z", name = "Zepto" },
	{ symbol = "y", name = "Yocto" },
}

local wolfram_base_units = {
	m = "Meters",
	s = "Seconds",
	A = "Amperes",
	K = "Kelvins",
	mol = "Moles",
	cd = "Candelas",
	Pa = "Pascals",
	N = "Newtons",
	J = "Joules",
	W = "Watts",
	V = "Volts",
	ohm = "Ohms",
	Hz = "Hertz",
	C = "Coulombs",
	F = "Farads",
	T = "Teslas",
	Wb = "Webers",
	H = "Henrys",
	lm = "Lumens",
	lx = "lux",
	Bq = "Becquerels",
	Gy = "Grays",
	Sv = "Sieverts",
	kat = "Katals",
	rad = "Radians",
	deg = "Degrees",
}

local function lowercase_first(text)
	return text:gsub("^%u", string.lower)
end

local function expand_prefixed_unit(unit_name)
	if wolfram_base_units[unit_name] then
		return nil
	end

	for _, prefix in ipairs(wolfram_unit_prefixes) do
		if unit_name:sub(1, #prefix.symbol) == prefix.symbol then
			local base = unit_name:sub(#prefix.symbol + 1)
			local base_name = wolfram_base_units[base]
			if base_name then
				return prefix.name .. lowercase_first(base_name)
			end
		end
	end

	return nil
end

function M.render_unit(node)
	if not node then
		return ""
	end

	if node.type == "unit_component" then
		local unit_name = node.name:gsub("^\\", "")
		return expand_prefixed_unit(unit_name) or unit_name
	elseif node.type == "superscript" then
		return M.render_unit(node.base) .. "^" .. M.render_unit(node.exponent)
	elseif node.type == "binary" then
		local left = M.render_unit(node.left)
		local right = M.render_unit(node.right)

		if node.operator == "/" then
			return left .. "/" .. right
		end
		return left .. " " .. right
	elseif node.type == "number" then
		return tostring(node.value)
	end

	return ""
end

return M
