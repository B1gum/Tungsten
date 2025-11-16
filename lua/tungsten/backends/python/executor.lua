-- lua/tungsten/backends/python/executor.lua
-- Provides function to convert AST to python (sympy) code and execute it

local render = require("tungsten.core.render")
local config = require("tungsten.config")
local logger = require("tungsten.util.logger")
local async = require("tungsten.util.async")
local handlers = require("tungsten.backends.python.handlers")

local M = {}

function M.ast_to_code(ast)
	handlers.ensure_handlers()

	if not ast then
		return "Error: AST is nil"
	end
	local registry = require("tungsten.core.registry")
	local registry_handlers = registry.get_handlers()
	if next(registry_handlers) == nil then
		return "Error: No Python handlers loaded for AST conversion."
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

	local ok, code = pcall(M.ast_to_code, ast)
	if not ok or not code then
		callback(nil, "Error converting AST to Python code: " .. tostring(code))
		return
	end

	if opts.code then
		code = opts.code
	end

	if config.numeric_mode or numeric then
		code = "sp.N(" .. code .. ")"
	end

	local command = table.concat({
		"import sympy as sp",
		"from sympy import *",
		"expr = " .. code,
		"print(sp.latex(expr))",
	}, "; ")

	local python_opts = (config.backend_opts and config.backend_opts.python) or {}
	local python_path = python_opts.python_path or "python3"
	async.run_job({ python_path, "-c", command }, {
		cache_key = cache_key,
		on_exit = function(exit_code, stdout, stderr)
			if exit_code == 0 then
				if stderr ~= "" then
					logger.debug("Tungsten Debug", "Tungsten Debug (stderr): " .. stderr)
				end
				callback(stdout, nil)
			else
				local err_msg
				if exit_code == -1 or exit_code == 127 then
					err_msg = "Python interpreter not found. Check python_path."
				else
					err_msg = ("Python interpreter exited with code %d"):format(exit_code)
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
		callback(nil, "Error converting AST to Python code: " .. tostring(code))
		return
	end

	local variables = {}
	for _, v in ipairs(solve_ast.variables or {}) do
		local ok, name = pcall(M.ast_to_code, v)
		table.insert(variables, ok and name or tostring(v.name or ""))
	end

	M.evaluate_async(nil, { code = code, cache_key = opts.cache_key }, function(result, err)
		if err then
			callback(nil, err)
			return
		end

		local parser = require("tungsten.backends.python.python_solution")
		local parsed = parser.parse_python_solution(result, variables, opts.is_system)
		if parsed.ok then
			callback(parsed.formatted, nil)
		else
			callback(nil, parsed.reason or "No solution")
		end
	end)
end

return M
