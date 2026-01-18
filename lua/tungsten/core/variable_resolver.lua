local lpeg = require("lpeglabel")

local P, Cs, C, R, B = lpeg.P, lpeg.Cs, lpeg.C, lpeg.R, lpeg.B
local word = R("AZ", "az", "09") + P("_")
local names_pattern_cache = {}

local VariableResolver = {}

local function build_names_pattern(names)
	local pattern = P(false)
	for _, name in ipairs(names) do
		pattern = pattern + P(name)
	end
	return pattern
end

local function get_names_pattern(variables_map)
	local names = vim.tbl_keys(variables_map)
	table.sort(names, function(a, b)
		return #a > #b
	end)

	local cache_key = table.concat(names, "\0")
	if names_pattern_cache[cache_key] then
		return names, names_pattern_cache[cache_key]
	end

	local pattern = build_names_pattern(names)
	names_pattern_cache[cache_key] = pattern
	return names, pattern
end

local function resolve_with_context(ctx, str, depth, stack)
	if depth >= ctx.max_depth then
		return str
	end

	local prev_depth, prev_stack = ctx.current_depth, ctx.current_stack
	ctx.current_depth, ctx.current_stack = depth, stack
	local result = ctx.final_pattern:match(str)
	ctx.current_depth, ctx.current_stack = prev_depth, prev_stack

	return result
end

local function replace_with_context(ctx, var)
	if ctx.current_stack[var] then
		return ctx.variables_map[var]
	end

	ctx.current_stack[var] = true

	local value = ctx.variables_map[var]
	local result = "(" .. resolve_with_context(ctx, value, ctx.current_depth + 1, ctx.current_stack) .. ")"
	ctx.current_stack[var] = nil

	return result
end

function VariableResolver.resolve(code_string, variables_map)
	if not variables_map or vim.tbl_isempty(variables_map) then
		return code_string
	end

	local names, pattern = get_names_pattern(variables_map)
	local ctx = {
		variables_map = variables_map,
		current_depth = 0,
		current_stack = {},
		max_depth = #names + 10,
	}

	ctx.final_pattern = Cs(((-B(word) * C(pattern) * -word) / function(var)
		return replace_with_context(ctx, var)
	end + 1) ^ 0)

	return resolve_with_context(ctx, code_string, 0, {})
end

return VariableResolver

