local job_manager = require("tungsten.domains.plotting.job_manager")
local plotting_io = require("tungsten.domains.plotting.io")
local free_vars = require("tungsten.domains.plotting.free_vars")
local classification = require("tungsten.domains.plotting.classification")
local parser = require("tungsten.core.parser")
local ast_mod = require("tungsten.core.ast")
local state = require("tungsten.state")

local M = {}

local DEFAULT_AXIS_SYMBOLS = {
	x = true,
	y = true,
	z = true,
	t = true,
	u = true,
	v = true,
	s = true,
	r = true,
	theta = true,
	phi = true,
	psi = true,
}

local BUILTIN_FUNCTIONS = {
	sin = true,
	cos = true,
	tan = true,
	cot = true,
	sec = true,
	csc = true,
	asin = true,
	acos = true,
	atan = true,
	sinh = true,
	cosh = true,
	tanh = true,
	asinh = true,
	acosh = true,
	atanh = true,
	exp = true,
	log = true,
	ln = true,
	sqrt = true,
	abs = true,
	erf = true,
	erfc = true,
	gamma = true,
	min = true,
	max = true,
	floor = true,
	ceil = true,
	round = true,
}

local function trim(str)
	if type(str) ~= "string" then
		return str
	end
	return (str:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function ensure_ast(opts)
	if type(opts.ast) == "table" then
		return opts.ast
	end
	local expr = trim(opts.expression or "")
	if expr == "" then
		return nil
	end
	local ok, parsed = pcall(parser.parse, expr, { simple_mode = true })
	if not ok or type(parsed) ~= "table" or type(parsed.series) ~= "table" then
		return nil
	end
	if #parsed.series == 1 then
		return parsed.series[1]
	end
	if ast_mod and ast_mod.create_sequence_node then
		return ast_mod.create_sequence_node(parsed.series)
	end
	return { type = "Sequence", nodes = parsed.series }
end

local function gather_nodes(root)
	if type(root) ~= "table" then
		return {}
	end
	if root.type == "Sequence" and type(root.nodes) == "table" then
		local nodes = {}
		for _, node in ipairs(root.nodes) do
			nodes[#nodes + 1] = node
		end
		return nodes
	end
	return { root }
end

local function mark_defined(defined, name)
	if type(name) ~= "string" then
		return
	end
	local cleaned = trim(name)
	if cleaned == "" then
		return
	end
	defined[cleaned] = true
	defined[cleaned:lower()] = true
	local base = cleaned:match("^([^%(]+)")
	if base then
		base = trim(base)
		if base ~= "" then
			defined[base] = true
			defined[base:lower()] = true
		end
	end
end

local function absorb_defined_from_list(defined, source)
	if type(source) == "table" then
		if #source > 0 then
			for _, name in ipairs(source) do
				mark_defined(defined, name)
			end
		else
			for name, enabled in pairs(source) do
				if enabled then
					mark_defined(defined, name)
				end
			end
		end
	elseif type(source) == "string" then
		mark_defined(defined, source)
	end
end

local function build_defined_names(opts)
	local defined = {}
	local persistent = state.persistent_variables or {}
	for name in pairs(persistent) do
		mark_defined(defined, name)
	end
	local definitions = opts.definitions
	if type(definitions) == "table" then
		for name in pairs(definitions) do
			if name ~= "__order" then
				mark_defined(defined, name)
			end
		end
	end
	local extra_sources = {
		opts.defined_symbols,
		opts.scoped_names,
		opts.bound_symbols,
		opts.known_symbols,
	}
	for _, source in ipairs(extra_sources) do
		absorb_defined_from_list(defined, source)
	end
	return defined
end

local function build_ignore_set(opts)
	local ignore = {}
	local function mark(name)
		if type(name) ~= "string" then
			return
		end
		ignore[name] = true
		ignore[name:lower()] = true
	end
	local sources = { opts.ignore_symbols, opts.ignored_symbols, opts.excluded_symbols }
	for _, source in ipairs(sources) do
		if type(source) == "table" then
			if #source > 0 then
				for _, name in ipairs(source) do
					mark(name)
				end
			else
				for name, enabled in pairs(source) do
					if enabled then
						mark(name)
					end
				end
			end
		elseif type(source) == "string" then
			mark(source)
		end
	end
	return ignore
end

local function build_axis_overrides(opts)
	local overrides = {}
	local function mark(name)
		if type(name) ~= "string" then
			return
		end
		overrides[name] = true
		overrides[name:lower()] = true
	end
	local candidates = { opts.axis_names, opts.independent_vars, opts.axis_symbols }
	for _, source in ipairs(candidates) do
		if type(source) == "table" then
			if #source > 0 then
				for _, name in ipairs(source) do
					mark(name)
				end
			else
				for name, enabled in pairs(source) do
					if enabled then
						mark(name)
					end
				end
			end
		elseif type(source) == "string" then
			mark(source)
		end
	end
	if next(overrides) == nil then
		return nil
	end
	return overrides
end

local function is_axis_name(name, overrides)
	if type(name) ~= "string" then
		return false
	end
	if overrides and (overrides[name] or overrides[name:lower()]) then
		return true
	end
	return DEFAULT_AXIS_SYMBOLS[name:lower()] or false
end

local function determine_axis_for_node(free_names, overrides)
	local axis = {}
	for _, name in ipairs(free_names) do
		if is_axis_name(name, overrides) then
			axis[name] = true
		end
	end
	return axis
end

local function looks_like_point_name(name)
	if type(name) ~= "string" then
		return false
	end
	if name:match("^[Pp]%d+$") or name:match("^[Pp]_%d+$") then
		return true
	end
	return false
end

local function sort_by_name(list)
	table.sort(list, function(a, b)
		local left = type(a.name) == "string" and a.name or ""
		local right = type(b.name) == "string" and b.name or ""
		return left < right
	end)
end

local function collect_point_entries(vars, opts, plot_dim)
	local entries = {}
	local point_names = {}
	local explicit = opts.point_symbols or opts.point_symbol_names
	if type(explicit) == "table" then
		if #explicit > 0 then
			for _, name in ipairs(explicit) do
				point_names[name] = true
			end
		else
			for name, enabled in pairs(explicit) do
				if enabled then
					point_names[name] = true
				end
			end
		end
	elseif type(explicit) == "string" then
		point_names[explicit] = true
	end
	local dim = plot_dim or opts.expected_dim or opts.dimension or opts.dim
	if type(dim) ~= "number" then
		dim = nil
	end
	for name in pairs(vars) do
		if point_names[name] or (dim and dim >= 3 and looks_like_point_name(name)) then
			local entry = { name = name, type = "point", point_dim = dim or 3 }
			if entry.point_dim >= 3 then
				entry.requires_point3 = true
			end
			entries[#entries + 1] = entry
			vars[name] = nil
		end
	end
	sort_by_name(entries)
	return entries
end

local function collect_function_calls(node, acc, seen)
	if type(node) ~= "table" or seen[node] then
		return
	end
	seen[node] = true
	if node.type == "function_call" then
		acc[#acc + 1] = node
	end
	for _, child in pairs(node) do
		if type(child) == "table" then
			if child.type then
				collect_function_calls(child, acc, seen)
			else
				for _, nested in pairs(child) do
					collect_function_calls(nested, acc, seen)
				end
			end
		end
	end
end

local function extract_function_name(node)
	if type(node) ~= "table" then
		return nil
	end
	if type(node.name) == "string" and node.name ~= "" then
		return node.name
	end
	local name_node = node.name_node
	if type(name_node) == "table" and type(name_node.name) == "string" then
		return name_node.name
	end
	return nil
end

local function build_function_entries(nodes, defined, ignored)
	local entries = {}
	local seen = {}
	local calls = {}
	for _, node in ipairs(nodes) do
		collect_function_calls(node, calls, {})
	end
	for _, fn in ipairs(calls) do
		local base = extract_function_name(fn)
		local lowered = base and base:lower()
		if base and not (defined[base] or defined[lowered] or ignored[base] or ignored[lowered]) then
			if not (lowered and BUILTIN_FUNCTIONS[lowered]) then
				local signature = ast_mod.canonical(fn)
				if signature then
					local sig_lower = signature:lower()
					if not (ignored[signature] or ignored[sig_lower] or seen[signature]) then
						entries[#entries + 1] = { name = signature, type = "function" }
						seen[signature] = true
					end
				end
			end
		end
	end
	sort_by_name(entries)
	return entries
end

local function build_variable_entries(vars)
	local entries = {}
	for name in pairs(vars) do
		entries[#entries + 1] = { name = name, type = "variable" }
	end
	sort_by_name(entries)
	return entries
end

function M.initiate_plot(plot_opts, on_success, on_error)
	return job_manager.submit(plot_opts or {}, on_success, on_error)
end

function M.get_undefined_symbols(opts)
	opts = opts or {}
	local root = ensure_ast(opts)
	if not root then
		return true, {}
	end
	local nodes = gather_nodes(root)
	if #nodes == 0 then
		return true, {}
	end
	local defined = build_defined_names(opts)
	local ignored = build_ignore_set(opts)
	local axis_overrides = build_axis_overrides(opts)
	local candidate_vars = {}
	local plot_dim = opts.dim or opts.dimension or opts.expected_dim
	local classification_opts = { simple_mode = true, mode = "simple" }
	for _, node in ipairs(nodes) do
		local ok_class, class_res = pcall(classification.analyze, node, classification_opts)
		if ok_class and type(class_res) == "table" and type(class_res.dim) == "number" then
			if type(plot_dim) ~= "number" or class_res.dim > plot_dim then
				plot_dim = class_res.dim
			end
		end
		local free = free_vars.find(node) or {}
		local axis_for_node = determine_axis_for_node(free, axis_overrides)
		for _, name in ipairs(free) do
			local lowered = type(name) == "string" and name:lower() or nil
			if
				not axis_for_node[name]
				and not defined[name]
				and not defined[lowered]
				and not ignored[name]
				and not ignored[lowered]
			then
				candidate_vars[name] = true
			end
		end
	end
	local points = collect_point_entries(candidate_vars, opts, plot_dim)
	local variables = build_variable_entries(candidate_vars)
	local functions = build_function_entries(nodes, defined, ignored)
	local ordered = {}
	for _, entry in ipairs(points) do
		ordered[#ordered + 1] = entry
	end
	for _, entry in ipairs(variables) do
		ordered[#ordered + 1] = entry
	end
	for _, entry in ipairs(functions) do
		ordered[#ordered + 1] = entry
	end
	return true, ordered
end

function M.generate_hash(plot_data)
	local opts = { filename_mode = "hash" }
	local generated = plotting_io.generate_filename(opts, plot_data or {})
	return generated:gsub("^plot_", "")
end

return M
