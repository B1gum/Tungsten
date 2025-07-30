-- engine.lua
-- Manages the interaction with the Wolfram Engine via wolframscript

local wolfram_codegen = require("tungsten.backends.wolfram")
local config = require("tungsten.config")
local state = require("tungsten.state")
local async = require("tungsten.util.async")
local logger = require("tungsten.util.logger")

local lpeg = require("lpeglabel")

local P, Cs, C, R, B = lpeg.P, lpeg.Cs, lpeg.C, lpeg.R, lpeg.B

local M = {}

function M.substitute_persistent_vars(code_string, variables_map)
	if not variables_map or vim.tbl_isempty(variables_map) then
		return code_string
	end

	local word = R("AZ", "az", "09") + P("_")
	local names = vim.tbl_keys(variables_map)
	table.sort(names, function(a, b)
		return #a > #b
	end)

	local pattern = P(false)
	for _, name in ipairs(names) do
		pattern = pattern + P(name)
	end

	local final_pattern
	local current_depth, current_stack
	local max_depth = #names + 10

	local function resolve(str, depth, stack)
		if depth >= max_depth then
			return str
		end

		local prev_depth, prev_stack = current_depth, current_stack
		current_depth, current_stack = depth, stack
		local result = final_pattern:match(str)
		current_depth, current_stack = prev_depth, prev_stack

		return result
	end

	local function replace(var)
		if current_stack[var] then
			return variables_map[var]
		end

		current_stack[var] = true

		local value = variables_map[var]
		local result = "(" .. resolve(value, current_depth + 1, current_stack) .. ")"
		current_stack[var] = nil

		return result
	end

	final_pattern = Cs(((-B(word) * C(pattern) * -word) / replace + 1) ^ 0)

	return resolve(code_string, 0, {})
end

local function get_cache_key(code_string, numeric)
	return code_string .. (numeric and "::numeric" or "::symbolic")
end
M.get_cache_key = get_cache_key

function M.evaluate_async(ast, numeric, callback)
	assert(type(callback) == "function", "evaluate_async expects a callback function")

	local initial_wolfram_code
	local pcall_ok, pcall_result = pcall(wolfram_codegen.ast_to_wolfram, ast)
	if not pcall_ok or pcall_result == nil then
		local err_msg = "Error converting AST to Wolfram code: " .. tostring(pcall_result)
		callback(nil, err_msg)
		return
	end
	initial_wolfram_code = pcall_result

	local code_with_vars_substituted = M.substitute_persistent_vars(initial_wolfram_code, state.persistent_variables)
	if code_with_vars_substituted ~= initial_wolfram_code then
		logger.debug(
			"Tungsten Debug",
			"Tungsten Debug: Code after persistent variable substitution: " .. code_with_vars_substituted
		)
	else
		logger.debug("Tungsten Debug", "Tungsten Debug: No persistent variable substitutions made.")
	end

	local cache_key = get_cache_key(code_with_vars_substituted, numeric)
	local use_cache = (config.cache_enabled == nil) or (config.cache_enabled == true)

	if use_cache then
		local cached = state.cache:get(cache_key)
		if cached then
			logger.info("Tungsten", "Tungsten: Result from cache.")
			logger.debug("Tungsten Debug", "Tungsten Debug: Cache hit for key: " .. cache_key)
			vim.schedule(function()
				callback(cached, nil)
			end)
			return
		end
	end

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
			return
		end
	end

	local code_to_execute = code_with_vars_substituted
	if config.numeric_mode or numeric then
		code_to_execute = "N[" .. code_to_execute .. "]"
	end

	code_to_execute = "ToString[TeXForm[" .. code_to_execute .. '], CharacterEncoding -> "UTF8"]'

	async.run_job({ config.wolfram_path, "-code", code_to_execute }, {
		cache_key = cache_key,
		on_exit = function(exit_code, final_stdout, final_stderr)
			if exit_code == 0 then
				if final_stderr ~= "" then
					logger.debug("Tungsten Debug", "Tungsten Debug (stderr): " .. final_stderr)
				end
				if use_cache then
					state.cache:set(cache_key, final_stdout)
					logger.info("Tungsten Debug", "Tungsten: Result for key '" .. cache_key .. "' stored in cache.")
				end
				callback(final_stdout, nil)
			else
				local err_msg
				if exit_code == -1 or exit_code == 127 then
					err_msg = "WolframScript not found. Check wolfram_path."
				else
					err_msg = ("WolframScript exited with code %d"):format(exit_code)
				end
				if final_stderr ~= "" then
					err_msg = err_msg .. "\nStderr: " .. final_stderr
				elseif final_stdout ~= "" then
					err_msg = err_msg .. "\nStdout (potentially error): " .. final_stdout
				end
				callback(nil, err_msg)
			end
		end,
	})
end

function M.clear_cache()
	state.cache:clear()
	logger.info("Tungsten", "Tungsten: Cache cleared.")
end

function M.get_active_jobs_summary()
	if vim.tbl_isempty(state.active_jobs) then
		return "Tungsten: No active jobs."
	end
	local report = { "Active Tungsten Jobs:" }
	for id, info in pairs(state.active_jobs) do
		local age_ms = 0
		if info.start_time then
			age_ms = vim.loop.now() - info.start_time
		end
		local age_str = string.format("%.1fs", age_ms / 1000)
		table.insert(
			report,
			("- ID: %s, Key: %s, Buf: %s, Age: %s"):format(tostring(id), info.cache_key, tostring(info.bufnr), age_str)
		)
	end
	return table.concat(report, "\n")
end

function M.view_active_jobs()
	local summary = M.get_active_jobs_summary()
	logger.info("Tungsten", summary)
end

return M
