-- engine.lua
-- Manages evaluation through the active backend

local manager = require("tungsten.backends.manager")
local config = require("tungsten.config")
local state = require("tungsten.state")
local logger = require("tungsten.util.logger")
local VariableResolver = require("tungsten.core.variable_resolver")

local M = {}

function M.substitute_persistent_vars(code_string, variables_map)
	return VariableResolver.resolve(code_string, variables_map)
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

	local code_with_vars_substituted = VariableResolver.resolve(initial_code, state.persistent_variables)
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
