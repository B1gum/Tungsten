-- lua/tungsten/core/solver.lua

local evaluator = require("tungsten.core.engine")
local config = require("tungsten.config")
local logger = require("tungsten.util.logger")
local state = require("tungsten.state")
local async = require("tungsten.util.async")
local solution_helper = require("tungsten.backends.wolfram.wolfram_solution")
local error_parser = require("tungsten.backends.wolfram.wolfram_error")
local wolfram_backend = require("tungsten.backends.wolfram")

local M = {}

local function construct_command(eq_strs, vars)
	local final_eqs = {}
	for _, eq in ipairs(eq_strs) do
		final_eqs[#final_eqs + 1] = evaluator.substitute_persistent_vars(eq, state.persistent_variables)
	end

	local eq_list = "{" .. table.concat(final_eqs, ", ") .. "}"
	local var_list = "{" .. table.concat(vars, ", ") .. "}"
	local base_cmd = string.format("Solve[%s, %s]", eq_list, var_list)
	logger.debug("Tungsten Debug", "TungstenSolve: Wolfram command: " .. base_cmd)
	local wolfram_cmd = "ToString[TeXForm[" .. base_cmd .. '], CharacterEncoding -> "UTF8"]'
	return wolfram_cmd, eq_list, var_list
end

local function parse_job_result(code, stdout, stderr, vars, is_system)
	if code == 0 then
		local out = stdout
		if stdout == "" and stderr ~= "" then
			logger.warn("Tungsten Solve", "TungstenSolve: Wolfram returned result via stderr: " .. stderr)
			out = stderr
		elseif stdout == "" and stderr == "" then
			logger.warn(
				"Tungsten Solve",
				"TungstenSolve: Wolfram returned empty stdout and stderr. No solution found or equation not solvable."
			)
		end
		local result = solution_helper.parse_wolfram_solution(out, vars, is_system)
		if result.ok then
			return result.formatted, nil
		else
			return nil, result.reason
		end
	end

	local parsed_err = error_parser.parse_wolfram_error(stderr)
	if parsed_err then
		return nil, parsed_err
	end

	local reason = code == -1 and "Command not found"
		or code == 0 and "Invalid arguments"
		or "exited with code " .. tostring(code)
	local err = code < 1
			and string.format("TungstenSolve: Failed to start WolframScript job for solving. (Reason: %s)", reason)
		or string.format(
			"TungstenSolve: WolframScript (Job N/A) error. Code: %s\nStderr: %s\nStdout: %s",
			tostring(code),
			stderr,
			stdout
		)
	return nil, err
end

function M.solve_equation_async(eq_strs, vars, is_system, callback)
	assert(
		callback and type(eq_strs) == "table" and type(vars) == "table",
		"solve_equation_async expects tables and a callback"
	)
	if #eq_strs == 0 then
		callback(nil, "No equations provided to solver.")
		return
	end
	if #vars == 0 then
		callback(nil, "No variables provided to solver.")
		return
	end
	local wolfram_command, eq_list, var_list = construct_command(eq_strs, vars)
	local cache_key = "solve:" .. eq_list .. "_for_" .. var_list

	async.run_job({ config.wolfram_path, "-code", wolfram_command }, {
		cache_key = cache_key,
		on_exit = function(code, stdout, stderr)
			local result, err = parse_job_result(code, stdout, stderr, vars, is_system)
			callback(result, err)
		end,
	})
end

function M.solve_asts_async(eq_asts, var_asts, is_system, callback)
	assert(
		callback and type(eq_asts) == "table" and type(var_asts) == "table",
		"solve_asts_async expects tables and a callback"
	)

	local eq_strs = {}
	for _, ast_node in ipairs(eq_asts) do
		local ok, str = pcall(wolfram_backend.ast_to_wolfram, ast_node)
		if not ok then
			callback(nil, "Failed to convert an equation to Wolfram string: " .. tostring(str))
			return
		end
		table.insert(eq_strs, str)
	end

	local var_strs = {}
	for _, var_node in ipairs(var_asts) do
		local ok, str = pcall(wolfram_backend.ast_to_wolfram, var_node)
		if not ok then
			callback(nil, "Failed to convert a variable to Wolfram string: " .. tostring(str))
			return
		end
		table.insert(var_strs, str)
	end

	M.solve_equation_async(eq_strs, var_strs, is_system, callback)
end

return M
