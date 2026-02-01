-- lua/tungsten/backends/python/executor.lua
-- Provides function to convert AST to python (sympy) code and execute it

local config = require("tungsten.config")
local ast_utils = require("tungsten.core.ast_utils")
local base_executor = require("tungsten.backends.base_executor")
local handlers = require("tungsten.backends.python.handlers")
local free_vars = require("tungsten.domains.plotting.free_vars")

local M = {}
M.display_name = "Python"
M.not_found_message = "Python interpreter not found. Check python_path."

local ScriptBuilder = {}
ScriptBuilder.__index = ScriptBuilder

function ScriptBuilder.new()
	return setmetatable({
		lines = {},
		expr = nil,
		numeric = false,
		has_units = false,
		is_unit_convert = false,
		form = "TeXForm",
	}, ScriptBuilder)
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

function ScriptBuilder:declare_variables(variables)
	if not variables or #variables == 0 then
		return self
	end
	for _, var in ipairs(variables) do
		table.insert(self.lines, ("%s = sp.Symbol('%s')"):format(var, var))
	end
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

function ScriptBuilder:set_units(has_units, is_unit_convert)
	self.has_units = has_units
	self.is_unit_convert = is_unit_convert
	return self
end

function ScriptBuilder:set_form(form)
	self.form = form or self.form
	return self
end

function ScriptBuilder:output_formatted()
	local expression = self.expr or ""
	if self.numeric then
		expression = ("sp.N(%s)"):format(expression)
	end
	if self.has_units and not self.is_unit_convert then
		expression = ("sp.simplify(%s)"):format(expression)
	end
	table.insert(self.lines, ("expr = %s"):format(expression))
	if self.form == "InputForm" then
		table.insert(self.lines, "print(sp.sstr(expr))")
	else
		table.insert(self.lines, "print(sp.latex(expr))")
	end
	return self
end

function ScriptBuilder:build()
	return table.concat(self.lines, "; ")
end

function M.get_interpreter_command()
	local python_opts = (config.backend_opts and config.backend_opts.python) or {}

	if python_opts.python_path then
		return python_opts.python_path
	end

	local info = debug.getinfo(1, "S")
	local source = info.source:sub(2)

	local plugin_root = source:match("(.*)/lua/tungsten/backends/python/executor%.lua$")

	if plugin_root then
		local venv_python = plugin_root .. "/.venv/bin/python"
		local venv_python_win = plugin_root .. "/.venv/Scripts/python.exe"

		if vim.fn.executable(venv_python) == 1 then
			return venv_python
		elseif vim.fn.executable(venv_python_win) == 1 then
			return venv_python_win
		end
	end

	return "python3"
end

local function build_python_config(opts, has_units_flag)
	opts = opts or {}
	local numeric = config.numeric_mode or opts.numeric
	local form = opts.form

	if not form then
		if (has_units_flag and not opts.is_unit_convert) or opts.is_unit_convert then
			form = "InputForm"
		else
			form = "TeXForm"
		end
	end

	return {
		numeric = numeric,
		form = form,
		has_units = has_units_flag,
		is_unit_convert = opts.is_unit_convert,
	}
end

function M.build_command(code, opts)
	local units_present = false
	local variables = {}
	if opts.ast then
		units_present = ast_utils.has_units(opts.ast)
		variables = free_vars.find(opts.ast)
	end

	local is_unit_convert = ast_utils.is_unit_convert_call(opts.ast)
	local build = build_python_config({
		numeric = opts.numeric,
		form = opts.form,
		is_unit_convert = is_unit_convert,
	}, units_present)

	local builder = ScriptBuilder.new()
		:add_import("sympy", "sp")
		:add_import("sympy.physics.units", "u")
		:add_from_import("sympy", "*")
		:declare_variables(variables)
		:set_expression(code)
		:set_units(build.has_units, build.is_unit_convert)
		:set_form(build.form)

	if build.numeric then
		builder:enable_numeric()
	end

	if opts.assignment and opts.variable_name then
		local expression = code
		if build.numeric then
			expression = ("sp.N(%s)"):format(expression)
		end
		table.insert(builder.lines, ("%s = %s"):format(opts.variable_name, expression))
		table.insert(builder.lines, ("print(sp.latex(%s))"):format(opts.variable_name))

		local command = builder:build()
		return { "-c", command }, { form = build.form }
	end

	local command = builder:output_formatted():build()

	return { "-c", command }, { form = build.form }
end

local function sanitize_python_output(stdout)
	if not stdout or stdout == "" then
		return stdout
	end

	local cleaned = {}
	for line in stdout:gmatch("[^\r\n]+") do
		if
			not line:match("SymPyDeprecationWarning")
			and not line:match("DeprecationWarning")
			and not line:match("FutureWarning")
			and not line:match("RuntimeWarning")
			and not line:match("UserWarning")
			and not line:match("^%s*WARNING")
			and not line:match("^%s*Warning:")
		then
			table.insert(cleaned, line)
		end
	end

	local result = table.concat(cleaned, "\n")
	return result:match("^%s*(.-)%s*$")
end

function M.sanitize_output(stdout)
	return sanitize_python_output(stdout)
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

function M.persistent_write_async(name, value, callback)
	local state = require("tungsten.state")
	local variable_resolver = require("tungsten.core.variable_resolver")

	local resolved_value = variable_resolver.resolve(value, state.persistent_variables or {})

	local opts = {
		code = resolved_value,
		variable_name = name,
		assignment = true,
	}
	M.evaluate_async(nil, opts, callback)
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

function M.prepare_solve_opts(solve_ast)
	return { form = "TeXForm", ast = solve_ast }
end

return M
