-- lua/tungsten/backends/wolfram/executor.lua
-- Provides function to convert AST to wolfram code and execute it

local render = require("tungsten.core.render")
local config = require("tungsten.config")
local logger = require("tungsten.util.logger")
local async = require("tungsten.util.async")
local handlers = require("tungsten.backends.wolfram.handlers")
local solution_parser = require("tungsten.backends.wolfram.wolfram_solution")

local M = {}

local function has_units(node)
	if type(node) ~= "table" then
		return false
	end
	if node.type == "quantity" or node.type == "unit_component" or node.type == "angle" then
		return true
	end
	for _, v in pairs(node) do
		if type(v) == "table" and has_units(v) then
			return true
		end
	end
	return false
end

function M.ast_to_code(ast)
	handlers.ensure_handlers()

	if not ast then
		return "Error: AST is nil"
	end
	local registry = require("tungsten.core.registry")
	local registry_handlers = registry.get_handlers()
	if next(registry_handlers) == nil then
		return "Error: No Wolfram handlers loaded for AST conversion."
	end

	local rendered_result = render.render(ast, registry_handlers)

	if type(rendered_result) == "table" and rendered_result.error then
		local error_message = rendered_result.message
		if rendered_result.node_type then
			error_message = error_message .. " (Node type: " .. rendered_result.node_type .. ")"
		end
		return "Error: AST rendering failed: " .. error_message
	end

	return rendered_result
end

function M.evaluate_async(ast, opts, callback)
	assert(type(callback) == "function", "evaluate_async expects callback")

	opts = opts or {}
	local numeric = opts.numeric
	local cache_key = opts.cache_key
	local form = opts.form

	local ok, code = pcall(M.ast_to_code, ast)
	if not ok or not code then
		callback(nil, "Error converting AST to Wolfram code: " .. tostring(code))
		return
	end

	if opts.code then
		code = opts.code
	end

	local units_present = false
	if ast then
		units_present = has_units(ast)
	end

	if config.numeric_mode or numeric then
		code = "N[" .. code .. "]"
	end

	if units_present then
		code = "Quiet[UnitSimplify[" .. code .. "]]"
		if not form then
			form = "InputForm"
		end
	end

	if not form then
		form = "TeXForm"
	end

	if form == "InputForm" then
		code = "ToString[" .. code .. ', CharacterEncoding -> "UTF8", FormatType -> InputForm]'
	else
		code = "ToString[TeXForm[" .. code .. '], CharacterEncoding -> "UTF8"]'
	end

	local wolfram_opts = (config.backend_opts and config.backend_opts.wolfram) or {}
	local wolfram_path = wolfram_opts.wolfram_path or "wolframscript"
	async.run_job({ wolfram_path, "-code", code }, {
		cache_key = cache_key,
		on_exit = function(exit_code, stdout, stderr)
			if exit_code == 0 then
				if stderr ~= "" then
					logger.debug("Tungsten Debug", "Tungsten Debug (stderr): " .. stderr)
				end

				local result = stdout

        result = result:gsub("\\theta", "u") -- Use u for the heaviside step function instead of theta

				if form == "InputForm" then
					local format_quantities = solution_parser.format_quantities or function(x)
						return x
					end
					result = format_quantities(result)
				end

				callback(result, nil)
			else
				local err_msg
				if exit_code == -1 or exit_code == 127 then
					err_msg = "WolframScript not found. Check wolfram_path."
				else
					err_msg = ("WolframScript exited with code %d"):format(exit_code)
				end
				if stderr ~= "" then
					err_msg = err_msg .. "\nStderr: " .. stderr
				elseif stdout ~= "" then
					err_msg = err_msg .. "\nStdout (potentially error): " .. stdout
				end
				callback(nil, err_msg)
			end
		end,
	})
end

function M.solve_async(solve_ast, opts, callback)
	assert(type(callback) == "function", "solve_async expects callback")

	opts = opts or {}
	local code_ok, code = pcall(M.ast_to_code, solve_ast)
	if not code_ok or not code then
		callback(nil, "Error converting AST to Wolfram code: " .. tostring(code))
		return
	end

	local variables = {}
	for _, v in ipairs(solve_ast.variables or {}) do
		local ok, name = pcall(M.ast_to_code, v)
		table.insert(variables, ok and name or tostring(v.name or ""))
	end

	M.evaluate_async(nil, { code = code, cache_key = opts.cache_key, form = "TeXForm" }, function(result, err)
		if err then
			callback(nil, err)
			return
		end

		local parser = require("tungsten.backends.wolfram.wolfram_solution")
		local parsed = parser.parse_wolfram_solution(result, variables, opts.is_system)
		if parsed.ok then
			callback(parsed.formatted, nil)
		else
			callback(nil, parsed.reason or "No solution")
		end
	end)
end

return M
