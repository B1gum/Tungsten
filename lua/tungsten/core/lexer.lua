-- core/lexer.lua
-- Handles lexical concerns such as delimiter-aware splitting.
------------------------------------------------------------

local M = {}

local delimiter_open_cmds = {
	["\\langle"] = true,
	["\\lfloor"] = true,
	["\\lceil"] = true,
	["\\lvert"] = true,
	["\\left|"] = true,
	["|"] = true,
}

local delimiter_close_cmds = {
	["\\rangle"] = true,
	["\\rfloor"] = true,
	["\\rceil"] = true,
	["\\rvert"] = true,
	["\\right|"] = true,
	["|"] = true,
}

local delimiter_replacements = {
	["\\langle"] = "(",
	["\\rangle"] = ")",
	["\\lvert"] = "|",
	["\\rvert"] = "|",
	["\\left|"] = "|",
	["\\right|"] = "|",
	["."] = "",
}

local function read_delimiter(str, i)
	local c = str:sub(i, i)
	if c == "\\" then
		local j = i + 1
		while j <= #str and str:sub(j, j):match("%a") do
			j = j + 1
		end
		return str:sub(i, j - 1), j - i
	else
		return c, 1
	end
end

local function split_top_level(str, seps)
	local parts = {}
	local current = {}
	local stack = {}
	local i, len = 1, #str
	local current_start = 1
	while i <= len do
		local c = str:sub(i, i)
		if c == "\\" then
			local next_five = str:sub(i, i + 4)
			local next_six = str:sub(i, i + 5)
			if next_five == "\\left" then
				table.insert(current, "\\left")
				i = i + 5
				local d, consumed = read_delimiter(str, i)
				local out = delimiter_replacements[d] or d
				if out ~= "" then
					table.insert(current, out)
				end
				table.insert(stack, d)
				i = i + consumed
			elseif next_six == "\\right" then
				table.insert(current, "\\right")
				i = i + 6
				local d, consumed = read_delimiter(str, i)
				local out = delimiter_replacements[d] or d
				if out ~= "" then
					table.insert(current, out)
				end
				if #stack > 0 then
					table.remove(stack)
				end
				i = i + consumed
			else
				local next_char = str:sub(i + 1, i + 1)
				if next_char ~= "" and not next_char:match("%a") then
					table.insert(current, str:sub(i, i + 1))
					i = i + 2
				else
					local j = i + 1
					while j <= len and str:sub(j, j):match("%a") do
						j = j + 1
					end
					local cmd = str:sub(i, j - 1)
					table.insert(current, delimiter_replacements[cmd] or cmd)
					if delimiter_open_cmds[cmd] then
						table.insert(stack, cmd)
					elseif delimiter_close_cmds[cmd] then
						if #stack > 0 then
							table.remove(stack)
						end
					end
					i = j
				end
			end
		else
			if c == "(" or c == "{" or c == "[" then
				table.insert(stack, c)
			elseif c == ")" or c == "}" or c == "]" then
				if #stack > 0 then
					table.remove(stack)
				end
			end
			if seps[c] and #stack == 0 then
				table.insert(parts, { str = table.concat(current), start_pos = current_start })
				current = {}
				i = i + 1
				current_start = i
			else
				table.insert(current, c)
				i = i + 1
			end
		end
	end
	table.insert(parts, { str = table.concat(current), start_pos = current_start })
	return parts
end

M.read_delimiter = read_delimiter
M.split_top_level = split_top_level
M.delimiter_open_cmds = delimiter_open_cmds
M.delimiter_close_cmds = delimiter_close_cmds
M.delimiter_replacements = delimiter_replacements

return M
