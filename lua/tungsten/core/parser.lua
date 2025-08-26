-- core/parser.lua
-- Parses input strings based on grammar into an AST
-----------------------------------------------------

local lpeg = require("lpeglabel")
local registry = require("tungsten.core.registry")
local space = require("tungsten.core.tokenizer").space
local logger = require("tungsten.util.logger")
local error_handler = require("tungsten.util.error_handler")
local ast = require("tungsten.core.ast")

local M = {}

local compiled_grammar

function M.get_grammar()
	if not compiled_grammar then
		logger.debug("Tungsten Parser", "Parser: Compiling combined grammar...")
		compiled_grammar = registry.get_combined_grammar()
		if not compiled_grammar then
			logger.error("Tungsten Parser Error", "Parser: Grammar compilation failed. Subsequent parsing will fail.")
			compiled_grammar = lpeg.P(false)
		else
			logger.debug("Tungsten Parser", "Parser: Combined grammar compiled and cached.")
		end
	end
	return compiled_grammar
end

local label_messages = {
	extra_input = "unexpected text after expression",
	fail = "syntax error",
}

local function top_level_split(str, seps)
	local parts = {}
	local current = {}
	local paren, brace, bracket = 0, 0, 0
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
				local d = str:sub(i, i)
				table.insert(current, d)
				if d == "(" then
					paren = paren + 1
				elseif d == "{" then
					brace = brace + 1
				elseif d == "[" then
					bracket = bracket + 1
				end
				i = i + 1
			elseif next_six == "\\right" then
				table.insert(current, "\\right")
				i = i + 6
				local d = str:sub(i, i)
				table.insert(current, d)
				if d == ")" then
					paren = paren - 1
				elseif d == "}" then
					brace = brace - 1
				elseif d == "]" then
					bracket = bracket - 1
				end
				i = i + 1
			else
				local j = i + 1
				while j <= len and str:sub(j, j):match("%a") do
					j = j + 1
				end
				table.insert(current, str:sub(i, j - 1))
				i = j
			end
		else
			if c == "(" then
				paren = paren + 1
			elseif c == ")" then
				paren = paren - 1
			elseif c == "{" then
				brace = brace + 1
			elseif c == "}" then
				brace = brace - 1
			elseif c == "[" then
				bracket = bracket + 1
			elseif c == "]" then
				bracket = bracket - 1
			end
			if seps[c] and paren == 0 and brace == 0 and bracket == 0 then
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

local function trim(s)
	local trimmed = s
	local leading = 0
	trimmed = trimmed:gsub("^%s+", function(w)
		leading = #w
		return ""
	end)
	trimmed = trimmed:gsub("%s+$", "")
	return trimmed, leading
end

function M.parse(input)
	local current_grammar = M.get_grammar()
	local pattern = space * current_grammar * (space * -1 + lpeg.T("extra_input"))

	local series_strs = top_level_split(input, { [";"] = true, ["\n"] = true })
	local series = {}
	for _, ser in ipairs(series_strs) do
		local seq_strs = top_level_split(ser.str, { [","] = true })
		local nodes = {}
		for _, item in ipairs(seq_strs) do
			local expr, lead = trim(item.str)
			if expr ~= "" then
				local result, err_label, err_pos = lpeg.match(pattern, expr)
				if not result then
					local tuple
					if expr:sub(1, 1) == "(" or expr:sub(1, 6) == "\\left(" then
						local inner, offset = nil, 0
						if expr:sub(1, 6) == "\\left(" and expr:sub(-7) == "\\right)" then
							inner = expr:sub(7, -8)
							offset = 6
						elseif expr:sub(1, 1) == "(" and expr:sub(-1) == ")" then
							inner = expr:sub(2, -2)
							offset = 1
						end
						if inner then
							local parts = top_level_split(inner, { [","] = true })
							if #parts == 2 or #parts == 3 then
								local elems = {}
								for _, p in ipairs(parts) do
									local subexpr = trim(p.str)
									local subres, sublabel, subpos = lpeg.match(pattern, subexpr)
									if not subres then
										local msg = label_messages[sublabel] or tostring(sublabel)
										if subpos then
											local global_pos = ser.start_pos + item.start_pos - 1 + offset + p.start_pos - 1 + subpos - 1
											msg = msg .. " at " .. error_handler.format_line_col(input, global_pos)
											return nil, msg, global_pos, input
										end
										return nil, msg, nil, input
									end
									table.insert(elems, subres)
								end
								if #elems == 2 then
									tuple = ast.create_point2_node(elems[1], elems[2])
								elseif #elems == 3 then
									tuple = ast.create_point3_node(elems[1], elems[2], elems[3])
								end
							end
						end
					end
					if not tuple then
						local msg = label_messages[err_label] or tostring(err_label)
						if err_pos then
							local global_pos = ser.start_pos + item.start_pos - 1 + lead + err_pos - 1
							msg = msg .. " at " .. error_handler.format_line_col(input, global_pos)
							return nil, msg, global_pos, input
						end
						return nil, msg, nil, input
					end
					result = tuple
				end
				table.insert(nodes, result)
			end
		end
		if #nodes == 1 then
			table.insert(series, nodes[1])
		elseif #nodes > 1 then
			table.insert(series, ast.create_sequence_node(nodes))
		end
	end

	return { series = series }
end

function M.reset_grammar()
	logger.info("Tungsten Parser", "Parser: Resetting compiled grammar.")
	compiled_grammar = nil
end

return M
