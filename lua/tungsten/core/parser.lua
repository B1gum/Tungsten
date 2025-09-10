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

local delimiter_open_cmds = {
	["\\langle"] = true,
	["\\lfloor"] = true,
	["\\lceil"] = true,
}

local delimiter_close_cmds = {
	["\\rangle"] = true,
	["\\rfloor"] = true,
	["\\rceil"] = true,
}

local delimiter_replacements = {
	["\\langle"] = "(",
	["\\rangle"] = ")",
}

local function read_delim(str, i)
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
				local d, consumed = read_delim(str, i)
				local out = delimiter_replacements[d] or d
				table.insert(current, out)
				if d == "(" then
					paren = paren + 1
				elseif d == "{" then
					brace = brace + 1
				elseif d == "[" or delimiter_open_cmds[d] then
					bracket = bracket + 1
				end
				i = i + consumed
			elseif next_six == "\\right" then
				table.insert(current, "\\right")
				i = i + 6
				local d, consumed = read_delim(str, i)
				local out = delimiter_replacements[d] or d
				table.insert(current, out)
				if d == ")" then
					paren = paren - 1
				elseif d == "}" then
					brace = brace - 1
				elseif d == "]" or delimiter_close_cmds[d] then
					bracket = bracket - 1
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
						bracket = bracket + 1
					elseif delimiter_close_cmds[cmd] then
						bracket = bracket - 1
					end
					i = j
				end
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

local function detect_chained_relations(expr)
	local paren, brace, bracket = 0, 0, 0
	local count = 0
	local i, len = 1, #expr
	while i <= len do
		local c = expr:sub(i, i)
		local advance = 1
		if c == "\\" then
			local next_five = expr:sub(i, i + 4)
			local next_six = expr:sub(i, i + 5)
			if next_five == "\\left" then
				local d, consumed = read_delim(expr, i + 5)
				if d == "(" then
					paren = paren + 1
				elseif d == "{" then
					brace = brace + 1
				elseif d == "[" or delimiter_open_cmds[d] then
					bracket = bracket + 1
				end
				advance = 5 + consumed
			elseif next_six == "\\right" then
				local d, consumed = read_delim(expr, i + 6)
				if d == ")" then
					paren = paren - 1
				elseif d == "}" then
					brace = brace - 1
				elseif d == "]" or delimiter_close_cmds[d] then
					bracket = bracket - 1
				end
				advance = 6 + consumed
			elseif expr:sub(i, i + 3) == "\\leq" then
				if paren == 0 and brace == 0 and bracket == 0 then
					count = count + 1
					if count > 1 then
						return i
					end
				end
				advance = 4
			elseif expr:sub(i, i + 2) == "\\le" then
				if paren == 0 and brace == 0 and bracket == 0 then
					count = count + 1
					if count > 1 then
						return i
					end
				end
				advance = 3
			elseif expr:sub(i, i + 3) == "\\geq" then
				if paren == 0 and brace == 0 and bracket == 0 then
					count = count + 1
					if count > 1 then
						return i
					end
				end
				advance = 4
			elseif expr:sub(i, i + 2) == "\\ge" then
				if paren == 0 and brace == 0 and bracket == 0 then
					count = count + 1
					if count > 1 then
						return i
					end
				end
				advance = 3
			else
				local j = i + 1
				while j <= len and expr:sub(j, j):match("%a") do
					j = j + 1
				end
				local cmd = expr:sub(i, j - 1)
				if delimiter_open_cmds[cmd] then
					bracket = bracket + 1
				elseif delimiter_close_cmds[cmd] then
					bracket = bracket - 1
				end
				advance = j - i
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
			elseif paren == 0 and brace == 0 and bracket == 0 then
				if c == "<" or c == ">" or c == "=" or c == "≤" or c == "≥" then
					if c == "<" or c == ">" then
						if expr:sub(i + 1, i + 1) == "=" then
							count = count + 1
							if count > 1 then
								return i
							end
							advance = 2
						else
							count = count + 1
							if count > 1 then
								return i
							end
						end
					else
						count = count + 1
						if count > 1 then
							return i
						end
					end
				end
			end
		end
		i = i + advance
	end
	return nil
end

local function contains_variable(node)
	if type(node) ~= "table" then
		return false
	end
	if node.type == "variable" then
		return true
	end
	for _, v in pairs(node) do
		if contains_variable(v) then
			return true
		end
	end
	return false
end

local function try_point_tuple(expr, pattern, ser_start, item_start, input, opts)
	local inner, offset = nil, 0
	if expr:sub(1, 6) == "\\left(" and expr:sub(-7) == "\\right)" then
		inner = expr:sub(7, -8)
		offset = 6
	elseif expr:sub(1, 1) == "(" and expr:sub(-1) == ")" then
		inner = expr:sub(2, -2)
		offset = 1
	end
	if not inner then
		return nil
	end

	local parts = top_level_split(inner, { [","] = true })
	if #parts == 2 or #parts == 3 then
		local elems = {}
		for _, p in ipairs(parts) do
			local subexpr, sublead = trim(p.str)
			local rel_pos = detect_chained_relations(subexpr)
			if rel_pos then
				local global_pos = ser_start + item_start - 1 + offset + p.start_pos - 1 + sublead + rel_pos - 1
				local msg = "Chained inequalities are not supported (v1)."
				return nil, msg, global_pos
			end
			local subres, sublabel, subpos = lpeg.match(pattern, subexpr)
			if not subres then
				local msg = label_messages[sublabel] or tostring(sublabel)
				if subpos then
					local global_pos = ser_start + item_start - 1 + offset + p.start_pos - 1 + sublead + subpos - 1
					msg = msg .. " at " .. error_handler.format_line_col(input, global_pos)
					return nil, msg, global_pos
				end
				return nil, msg
			end
			table.insert(elems, subres)
		end

		if opts and opts.mode == "advanced" then
			if opts.form == "parametric" then
				local has_var = false
				for _, e in ipairs(elems) do
					if contains_variable(e) then
						has_var = true
						break
					end
				end
				if has_var then
					if #elems == 2 then
						return ast.create_parametric2d_node(elems[1], elems[2])
					else
						return ast.create_parametric3d_node(elems[1], elems[2], elems[3])
					end
				end
			elseif opts.form == "polar" then
				if #elems ~= 2 then
					local global_pos = ser_start + item_start - 1 + offset + parts[3].start_pos - 1
					local msg = "Polar typles support only 2D at " .. error_handler.format_line_col(input, global_pos)
					return nil, msg, global_pos
				end
				local r, theta = elems[1], elems[2]
				if theta.type ~= "variable" or theta.name ~= "theta" then
					local global_pos = ser_start + item_start - 1 + offset + parts[2].start_pos - 1
					local msg = "Polar tuples must have theta as second element at "
						.. error_handler.format_line_col(input, global_pos)
					return nil, msg, global_pos
				end
				return ast.create_polar2d_node(r)
			end
		end

		if #elems == 2 then
			return ast.create_point2_node(elems[1], elems[2])
		else
			return ast.create_point3_node(elems[1], elems[2], elems[3])
		end
	elseif #parts > 3 then
		local global_pos = ser_start + item_start - 1 + offset + parts[4].start_pos - 1
		local msg = "Point tuples support only 2D or 3D at " .. error_handler.format_line_col(input, global_pos)
		return nil, msg, global_pos
	end
	return nil
end

function M.parse(input, opts)
	opts = opts or {}
	local current_grammar = M.get_grammar()
	local pattern = space * current_grammar * (space * -1 + lpeg.T("extra_input"))

	local series_strs = top_level_split(input, { [";"] = true, ["\n"] = true })
	local series = {}
	for _, ser in ipairs(series_strs) do
		local seq_strs = top_level_split(ser.str, { [","] = true })
		local nodes = {}
		local point_dim
		for _, item in ipairs(seq_strs) do
			local expr, lead = trim(item.str)
			if expr ~= "" then
				local rel_pos = detect_chained_relations(expr)
				if rel_pos then
					local global_pos = ser.start_pos + item.start_pos - 1 + lead + rel_pos - 1
					local msg = "Chained inequalities are not supported (v1)."
					return nil, msg, global_pos, input
				end

				local tuple, tuple_err, tuple_pos
				if expr:sub(1, 1) == "(" or expr:sub(1, 6) == "\\left(" then
					tuple, tuple_err, tuple_pos = try_point_tuple(expr, pattern, ser.start_pos, item.start_pos, input, opts)
					if tuple_err then
						return nil, tuple_err, tuple_pos, input
					end
				end

				local result, err_label, err_pos
				if tuple then
					result = tuple
				else
					result, err_label, err_pos = lpeg.match(pattern, expr)
					if not result then
						local msg = label_messages[err_label] or tostring(err_label)
						if err_pos then
							local global_pos = ser.start_pos + item.start_pos - 1 + lead + err_pos - 1
							msg = msg .. " at " .. error_handler.format_line_col(input, global_pos)
							return nil, msg, global_pos, input
						end
						return nil, msg, nil, input
					end
				end

				if result.type == "Point2" or result.type == "Point3" then
					local dim = result.type == "Point2" and 2 or 3
					if point_dim and point_dim ~= dim then
						local global_pos = ser.start_pos + item.start_pos - 1 + lead
						local msg = "Cannot mix 2D and 3D points in the same sequence or series at "
							.. error_handler.format_line_col(input, global_pos)
						return nil, msg, global_pos, input
					end
					point_dim = point_dim or dim
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
