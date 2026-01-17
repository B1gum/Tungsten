-- engine.lua
-- Manages evaluation through the active backend

local manager = require("tungsten.backends.manager")
local config = require("tungsten.config")
local state = require("tungsten.state")
local logger = require("tungsten.util.logger")

local lpeg = require("lpeglabel")

local P, Cs, C, R, B = lpeg.P, lpeg.Cs, lpeg.C, lpeg.R, lpeg.B
local word = R("AZ", "az", "09") + P("_")
local names_pattern_cache = {}

local M = {}

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

function M.substitute_persistent_vars(code_string, variables_map)
	if not variables_map or vim.tbl_isempty(variables_map) then
		return code_string
	end

	local names, pattern = get_names_pattern(variables_map)
	local ctx = {
		variables_map = variables_map,
		current_depth = 0,
		current_stack = {},
		-- Safety valve: stop expanding if there are cycles or unusually deep chains.
		-- The maximum depth scales with the number of variables to avoid runaway recursion.
		max_depth = #names + 10,
	}

	ctx.final_pattern = Cs(((-B(word) * C(pattern) * -word) / function(var)
		return replace_with_context(ctx, var)
	end + 1) ^ 0)

	return resolve_with_context(ctx, code_string, 0, {})
end

local function get_cache_key(code_string, numeric)
	return code_string .. (numeric and "::numeric" or "::symbolic")
end
M.get_cache_key = get_cache_key

local function try_get_cached_result(cache_key, use_cache, callback)
	if not use_cache then
		return false
	end

	local cached = state.cache:get(cache_key)
	if not cached then
		return false
	end

	logger.info("Tungsten", "Tungsten: Result from cache.")
	logger.debug("Tungsten Debug", "Tungsten Debug: Cache hit for key: " .. cache_key)
	vim.schedule(function()
		callback(cached, nil)
	end)
	return true
end

local function is_job_already_running(cache_key)
	for job_id_running, job_info in pairs(state.active_jobs) do
		if job_info.cache_key == cache_key then
			local notify_msg = "Tungsten: Evaluation already in progress for this expression."
			logger.info("Tungsten", notify_msg)
			logger.debug(
				"Tungsten Debug",
				("Tungsten: Evaluation already in progress for key: '%s' (Job ID: %s)"):format(
					cache_key,
					tostring(job_id_running)
				)
			)
			logger.notify(notify_msg, logger.levels.INFO, { title = "Tungsten" })
			return true
		end
	end

	return false
end

function M.evaluate_async(ast, numeric, callback)
	assert(type(callback) == "function", "evaluate_async expects a callback function")

	local backend = manager.current()
	if not backend then
		callback(nil, "No active backend")
		return
	end

	local ast_to_code = backend.ast_to_code
	local initial_code
	local pcall_ok, pcall_result = pcall(ast_to_code, ast)
	if not pcall_ok or pcall_result == nil then
		local err_msg = "Error converting AST to code: " .. tostring(pcall_result)
		callback(nil, err_msg)
		return
	end
	initial_code = pcall_result

	local code_with_vars_substituted = M.substitute_persistent_vars(initial_code, state.persistent_variables)
	if code_with_vars_substituted ~= initial_code then
		logger.debug("Tungsten Debug", "Code after persistent variable substitution: " .. code_with_vars_substituted)
	else
		logger.debug("Tungsten Debug", "No persistent variable substitutions made.")
	end

	local cache_key = get_cache_key(code_with_vars_substituted, numeric)
	local use_cache = (config.cache_enabled == nil) or (config.cache_enabled == true)

	if try_get_cached_result(cache_key, use_cache, callback) then
		return
	end

	if is_job_already_running(cache_key) then
		return
	end

	backend.evaluate_async(
		ast,
		{ numeric = numeric, code = code_with_vars_substituted, cache_key = cache_key },
		function(final_stdout, err)
			if not err and use_cache then
				state.cache:set(cache_key, final_stdout)
				logger.info("Tungsten Debug", "Tungsten: Result for key '" .. cache_key .. "' stored in cache.")
			end
			callback(final_stdout, err)
		end
	)
end

function M.clear_cache()
	state.cache:clear()
	logger.info("Tungsten", "Tungsten: Cache cleared.")
end

function M.get_active_jobs()
	return state.active_jobs
end

return M
