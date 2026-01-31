-- lua/tungsten/backends/python/executor.lua
-- Provides function to convert AST to python (sympy) code and execute it

local config = require("tungsten.config")
local base_executor = require("tungsten.backends.base_executor")
local handlers = require("tungsten.backends.python.handlers")

local M = {}
M.display_name = "Python"
M.not_found_message = "Python interpreter not found. Check python_path."

local ScriptBuilder = {}
ScriptBuilder.__index = ScriptBuilder

function ScriptBuilder.new()
	return setmetatable({ lines = {}, expr = nil, numeric = false }, ScriptBuilder)
end

function ScriptBuilder:add_import(module, alias)
	local statement = ("import %s"):format(module)
	if alias then
		statement = ("%s as %s"):format(statement, alias)
	end
	table.insert(self.lines, statement)
	return self
end

function ScriptBuilder:add_from_import(module, items)
	table.insert(self.lines, ("from %s import %s"):format(module, items))
	return self
end

function ScriptBuilder:set_expression(expr)
	self.expr = expr
	return self
end

function ScriptBuilder:enable_numeric()
	self.numeric = true
	return self
end

function ScriptBuilder:output_latex()
	local expression = self.expr or ""
	if self.numeric then
		expression = ("sp.N(%s)"):format(expression)
	end
	table.insert(self.lines, ("expr = %s"):format(expression))
	table.insert(self.lines, "print(sp.latex(expr))")
	return self
end

function ScriptBuilder:build()
	return table.concat(self.lines, "; ")
end

function M.get_interpreter_command()
	local python_opts = (config.backend_opts and config.backend_opts.python) or {}
	return python_opts.python_path or "python3"
end

function M.build_command(code, opts)
	local builder = ScriptBuilder.new()
		:add_import("sympy", "sp")
		:add_import("sympy.physics.units", "u")
		:add_from_import("sympy", "*")
		:set_expression(code)

	if config.numeric_mode or opts.numeric then
		builder:enable_numeric()
	end

	local command = builder:output_latex():build()

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
	return base_executor.ast_to_code(M, ast, {
		ensure_handlers = handlers.ensure_handlers,
		handlers_label = M.display_name,
	})
end

function M.exit_error(exit_code)
	return ("Python interpreter exited with code %d"):format(exit_code)
end

function M.evaluate_async(ast, opts, callback)
	return base_executor.evaluate_async(M, ast, opts, callback)
end

function M.evaluate_persistent(ast, opts, callback)
	return base_executor.evaluate_persistent(M, ast, opts, callback)
end

function M.solve_async(solve_ast, opts, callback)
	return base_executor.solve_async(M, solve_ast, opts, callback)
end

function M.get_persistent_command()
	local cmd = M.get_interpreter_command()
	return { cmd, "-q", "-u" }
end

function M.get_persistent_init()
	return "import sys; sys.ps1=''; sys.ps2=''; import sympy as sp; import sympy.physics.units as u; from sympy import *"
end

function M.format_persistent_init(code, delimiter)
	return string.format("%s\nprint('%s')", code, delimiter)
end

function M.format_persistent_input(code, delimiter)
	return string.format("print(sp.latex(%s))\nprint('%s')", code, delimiter)
end

return M
