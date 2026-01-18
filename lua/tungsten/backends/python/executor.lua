-- lua/tungsten/backends/python/executor.lua
-- Provides function to convert AST to python (sympy) code and execute it

local render = require("tungsten.core.render")
local config = require("tungsten.config")
local base_executor = require("tungsten.backends.base_executor")
local handlers = require("tungsten.backends.python.handlers")

local M = {}
M.display_name = "Python"
M.not_found_message = "Python interpreter not found. Check python_path."

function M.get_interpreter_command()
	local python_opts = (config.backend_opts and config.backend_opts.python) or {}
	return python_opts.python_path or "python3"
end

function M.build_command(code, opts)
	local final_code = code

	if config.numeric_mode or opts.numeric then
		final_code = "sp.N(" .. final_code .. ")"
	end

	local command = table.concat({
		"import sympy as sp",
		"from sympy import *",
		"expr = " .. final_code,
		"print(sp.latex(expr))",
	}, "; ")

	return { "-c", command }
end

function M.sanitize_output(stdout)
	return stdout
end

function M.parse_solution(result, variables, opts)
	local parser = require("tungsten.backends.python.python_solution")
	return parser.parse_python_solution(result, variables, opts.is_system)
end

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

function M.exit_error(exit_code)
	return ("Python interpreter exited with code %d"):format(exit_code)
end

function M.evaluate_async(ast, opts, callback)
	return base_executor.evaluate_async(M, ast, opts, callback)
end

function M.solve_async(solve_ast, opts, callback)
	return base_executor.solve_async(M, solve_ast, opts, callback)
end

return M
