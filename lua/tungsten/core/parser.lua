-- core/parser.lua
-- Parses input strings based on grammar into an AST
-----------------------------------------------------

local lpeg = require("lpeglabel")
local registry = require("tungsten.core.registry")
local space = require("tungsten.core.tokenizer").space
local lexer = require("tungsten.core.lexer")
local validator = require("tungsten.core.validator")
local logger = require("tungsten.util.logger")
local error_handler = require("tungsten.util.error_handler")
local ast = require("tungsten.core.ast")
local helpers = require("tungsten.domains.plotting.helpers")
local semantic_pass = require("tungsten.core.semantic_pass")

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

local delimiter_open_cmds = lexer.delimiter_open_cmds
local delimiter_close_cmds = lexer.delimiter_close_cmds

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

local relation_pattern = lpeg.P("\\leq")
	+ lpeg.P("\\le")
	+ lpeg.P("\\geq")
	+ lpeg.P("\\ge")
	+ lpeg.P("<=")
	+ lpeg.P(">=")
	+ lpeg.P("≤")
	+ lpeg.P("≥")
	+ lpeg.P("<")
	+ lpeg.P(">")
	+ lpeg.P("=")

local function update_delimiter_state(state, delimiter, delta)
	if delimiter == "(" or delimiter == ")" then
		state.paren = state.paren + delta
	elseif delimiter == "{" or delimiter == "}" then
		state.brace = state.brace + delta
	elseif
		delimiter == "["
		or delimiter == "]"
		or delimiter_open_cmds[delimiter]
		or delimiter_close_cmds[delimiter]
		or delimiter == "."
	then
		state.bracket = state.bracket + delta
	end
end

local function consume_delimiter_command(expr, i, state)
	local next_five = expr:sub(i, i + 4)
	if next_five == "\\left" then
		local delimiter, consumed = lexer.read_delimiter(expr, i + 5)
		update_delimiter_state(state, delimiter, 1)
		return 5 + consumed
	end

	local next_six = expr:sub(i, i + 5)
	if next_six == "\\right" then
		local delimiter, consumed = lexer.read_delimiter(expr, i + 6)
		update_delimiter_state(state, delimiter, -1)
		return 6 + consumed
	end

	local j = i + 1
	local len = #expr
	while j <= len and expr:sub(j, j):match("%a") do
		j = j + 1
	end
	local cmd = expr:sub(i, j - 1)
	update_delimiter_state(state, cmd, delimiter_open_cmds[cmd] and 1 or delimiter_close_cmds[cmd] and -1 or 0)
	return j - i
end

local function detect_chained_relations(expr)
	local state = { paren = 0, brace = 0, bracket = 0 }
	local count = 0
	local i, len = 1, #expr
	while i <= len do
		local advance = 1
		local at_top = state.paren == 0 and state.brace == 0 and state.bracket == 0
		if at_top then
			local relation_end = lpeg.match(relation_pattern, expr, i)
			if relation_end then
				count = count + 1
				if count > 1 then
					return i
				end
				advance = relation_end - i
			end
		end

		if advance == 1 then
			local c = expr:sub(i, i)
			if c == "\\" then
				advance = consume_delimiter_command(expr, i, state)
			elseif c == "(" or c == ")" or c == "{" or c == "}" or c == "[" or c == "]" then
				local delta = (c == "(" or c == "{" or c == "[") and 1 or -1
				update_delimiter_state(state, c, delta)
			end
		end
		i = i + advance
	end
	return nil
end

local function collect_parametric_union(elements)
	local elem_params = {}
	local union_set = {}
	for i, element in ipairs(elements) do
		local params = helpers.extract_param_names(element)
		elem_params[i] = params
		for _, param in ipairs(params) do
			union_set[param] = true
		end
		end

	local union = {}
	for param in pairs(union_set) do
		table.insert(union, param)
	end
	table.sort(union)

	return elem_params, union_set, union
end

local function elements_share_union(elem_params, union_set, union)
	for _, params in ipairs(elem_params) do
		if #params ~= #union then
			return false
		end
		for _, name in ipairs(params) do
			if not union_set[name] then
				return false
			end
		end
  end
  return true
end

local function try_create_parametric_node(elements, opts)
	local mode = opts and opts.mode
	local form = opts and opts.form
	if mode ~= "advanced" or form ~= "parametric" then
		return nil
	end

	local element_count = #elements
	local elem_params, union_set, union = collect_parametric_union(elements)
	if not elements_share_union(elem_params, union_set, union) then
		return nil
	end

	if element_count == 2 then
		if #union == 1 and union[1] == "t" then
			return ast.create_parametric2d_node(elements[1], elements[2])
		end
	elseif element_count == 3 then
		if #union == 2 and union[1] == "u" and union[2] == "v" then
			return ast.create_parametric3d_node(elements[1], elements[2], elements[3])
		end
	end

	return nil
end

local function try_create_polar_node(elements, opts)
	if not opts or opts.form ~= "polar" or #elements ~= 2 then
		return nil
	end
	return ast.create_polar2d_node(elements[1])
end

local function create_tuple_node(elements, opts, context_info)
	local tuple_node = try_create_parametric_node(elements, opts)
	if tuple_node then
		return tuple_node, context_info
	end

	tuple_node = try_create_polar_node(elements, opts)
	if tuple_node then
		return tuple_node, context_info
	end

	if #elements == 2 then
		return ast.create_point2_node(elements[1], elements[2]), context_info
	end

	return ast.create_point3_node(elements[1], elements[2], elements[3]), context_info
end

local function try_point_tuple(expr, pattern, ser_start, item_start, input, opts, lead)
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

	local base_offset = ser_start + item_start - 1 + (lead or 0)

	local parts = lexer.split_top_level(inner, { [","] = true })
	if #parts == 2 or #parts == 3 then
		local elems = {}
		local part_meta = {}
		for idx, p in ipairs(parts) do
			local subexpr, sublead = trim(p.str)
			part_meta[idx] = { start_pos = p.start_pos, trim_leading = sublead }
			local rel_pos = detect_chained_relations(subexpr)
			if rel_pos then
				local global_pos = base_offset + offset + p.start_pos - 1 + sublead + rel_pos - 1
				local msg = "Chained inequalities are not supported (v1)."
				return nil, msg, global_pos
			end
			local subres, sublabel, subpos = lpeg.match(pattern, subexpr)
			if not subres then
				local msg = label_messages[sublabel] or tostring(sublabel)
				if subpos then
					local global_pos = base_offset + offset + p.start_pos - 1 + sublead + subpos - 1
					msg = msg .. " at " .. error_handler.format_line_col(input, global_pos)
					return nil, msg, global_pos
				end
				return nil, msg
			end
			table.insert(elems, subres)
		end

		local tuple_node = create_tuple_node(elems, opts, { element_count = #elems })

		tuple_node._tuple_meta = {
			base_offset = base_offset + offset,
			parts = part_meta,
			input = input,
			elements = elems,
			opts = { mode = opts and opts.mode, form = opts and opts.form },
		}

		tuple_node._source = { input = input, start_pos = base_offset }

		return tuple_node
	elseif #parts > 3 then
		local global_pos = base_offset + offset + parts[4].start_pos - 1
		local msg = "Point tuples support only 2D or 3D at " .. error_handler.format_line_col(input, global_pos)
		return nil, msg, global_pos
	end
	return nil
end

local function tokenize_structure(input)
	local series_strs = lexer.split_top_level(input, { [";"] = true })
	local structure = {}
	for _, ser in ipairs(series_strs) do
		local seq_strs = lexer.split_top_level(ser.str, { [","] = true })
		table.insert(structure, { start_pos = ser.start_pos, items = seq_strs })
	end
	return structure
end

local function parse_expression_item(expr, pattern, ser_start, item_start, opts)
	local input = opts and opts.input
	local trimmed, lead = trim(expr)
	if trimmed == "" then
		return nil
	end

	local rel_pos = (not opts.allow_multiple_relations) and detect_chained_relations(trimmed)
	if rel_pos then
		local global_pos = ser_start + item_start - 1 + lead + rel_pos - 1
		local msg = "Chained inequalities are not supported (v1)."
		return nil, msg, global_pos
	end

	local tuple, tuple_err, tuple_pos
	if trimmed:sub(1, 1) == "(" or trimmed:sub(1, 6) == "\\left(" then
		tuple, tuple_err, tuple_pos = try_point_tuple(trimmed, pattern, ser_start, item_start, input, opts, lead)
		if tuple_err then
			return nil, tuple_err, tuple_pos
		end
	end

	if tuple then
		return tuple
	end

	local result, err_label, err_pos = lpeg.match(pattern, trimmed)
	if not result then
		local msg = label_messages[err_label] or tostring(err_label)
		if err_pos then
			local global_pos = ser_start + item_start - 1 + lead + err_pos - 1
			msg = msg .. " at " .. error_handler.format_line_col(input, global_pos)
			return nil, msg, global_pos
		end
		return nil, msg
	end

	return result
end

local function post_process_series(series, opts)
	if not (opts and opts.allow_multiple_relations) or #series == 0 then
		return series
	end

	local equations = {}
	local has_non_equation = false
	local function collect_eqs(node)
		if not node then
			return
		end
		if node.type == "Sequence" and node.nodes then
			for _, child in ipairs(node.nodes) do
				collect_eqs(child)
			end
			return
		end

		if node.type == "Equality" then
			table.insert(equations, node)
		else
			has_non_equation = true
		end
	end

	for _, node in ipairs(series) do
		collect_eqs(node)
	end

	if #equations > 1 and not has_non_equation then
		return { ast.create_solve_system_equations_capture_node(equations) }
	end

	return series
end

function M.parse(input, opts)
	opts = opts or {}
	if opts.allow_multiple_relations then
		input = input:gsub("\\\\%s*\n", ";"):gsub("\\\\", ";")
	end
	local current_grammar = M.get_grammar()
	local pattern = space * current_grammar * (space * -1 + lpeg.T("extra_input"))
	local parse_opts = {}
	for key, value in pairs(opts) do
		parse_opts[key] = value
	end
	parse_opts.input = input

	local series = {}
	for _, ser in ipairs(tokenize_structure(input)) do
		local nodes = {}
		for _, item in ipairs(ser.items) do
			local result, err_msg, err_pos =
				parse_expression_item(item.str, pattern, ser.start_pos, item.start_pos, parse_opts)
			if err_msg then
				return nil, err_msg, err_pos, input
			end
			if result then
				table.insert(nodes, result)
			end
		end
		if #nodes == 1 then
			table.insert(series, nodes[1])
		elseif #nodes > 1 then
			local sequence_node = ast.create_sequence_node(nodes)
			table.insert(series, sequence_node)
		end
	end

	series = post_process_series(series, opts)

	local ast_root = { series = series }

	local valid, validation_err, validation_pos = validator.validate(ast_root, opts)
	if not valid then
		return nil, validation_err, validation_pos, input
	end

	ast_root = semantic_pass.apply(ast_root)
	return ast_root
end

function M.reset_grammar()
	logger.info("Tungsten Parser", "Parser: Resetting compiled grammar.")
	compiled_grammar = nil
end

return M
