-- engine.lua
-- Manages evaluation through the active backend

local manager = require("tungsten.backends.manager")
local state = require("tungsten.state")
local logger = require("tungsten.util.logger")
local CacheService = require("tungsten.core.cache_service")
local JobCoordinator = require("tungsten.core.job_coordinator")
local VariableResolver = require("tungsten.core.variable_resolver")

local M = {}

function M.substitute_persistent_vars(code_string, variables_map)
	return VariableResolver.resolve(code_string, variables_map)
end

function M.get_cache_key(code_string, numeric)
	return CacheService.get_cache_key(code_string, numeric)
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

	local cache_key = CacheService.get_cache_key(code_with_vars_substituted, numeric)
	local use_cache = CacheService.should_use_cache()

	if CacheService.try_get(cache_key, use_cache, callback) then
		return
	end

	if JobCoordinator.is_job_already_running(cache_key) then
		return
	end

	backend.evaluate_async(
		ast,
		{ numeric = numeric, code = code_with_vars_substituted, cache_key = cache_key },
		function(final_stdout, err)
			if not err and use_cache then
				CacheService.store(cache_key, final_stdout)
			end
			callback(final_stdout, err)
		end
	)
end

function M.clear_cache()
	CacheService.clear()
end

function M.get_active_jobs()
	return state.active_jobs
end

return M
