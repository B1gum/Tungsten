-- lua/tungsten/backends/python/executor.lua
local config = require("tungsten.config")
local ast_utils = require("tungsten.core.ast_utils")
local base_executor = require("tungsten.backends.base_executor")
local handlers = require("tungsten.backends.python.handlers")
local constants = require("tungsten.core.constants")

local M = {}
M.display_name = "Python"
M.not_found_message = "Python interpreter not found. Check python_path."

local APPLY_HELPER =
	"_apply = lambda f, *args: f.func(*args) if isinstance(f, sp.core.function.AppliedUndef) else f(*args)"

local MATRIX_PATCH = [[exec("""
_orig_add = sp.MatrixBase.__add__
_orig_sub = sp.MatrixBase.__sub__
def _mx_add(s, o):
    try: return _orig_add(s, o)
    except TypeError: return s.applyfunc(lambda x: x + o)
def _mx_radd(s, o):
    try: return _orig_add(s, o)
    except TypeError: return s.applyfunc(lambda x: o + x)
def _mx_sub(s, o):
    try: return _orig_sub(s, o)
    except TypeError: return s.applyfunc(lambda x: x - o)
def _mx_rsub(s, o):
    return s.applyfunc(lambda x: o - x)
sp.MatrixBase.__add__ = _mx_add
sp.MatrixBase.__radd__ = _mx_radd
sp.MatrixBase.__sub__ = _mx_sub
sp.MatrixBase.__rsub__ = _mx_rsub
""")]]

local BUILTIN_FUNCTIONS = {
	sin = true,
	cos = true,
	tan = true,
	sec = true,
	csc = true,
	cot = true,
	asin = true,
	acos = true,
	atan = true,
	sinh = true,
	cosh = true,
	tanh = true,
	asinh = true,
	acosh = true,
	atanh = true,
	exp = true,
	log = true,
	ln = true,
	sqrt = true,
	root = true,
	abs = true,
	re = true,
	im = true,
	arg = true,
	conjugate = true,
	Heaviside = true,
	DiracDelta = true,
	gamma = true,
	factorial = true,
	erf = true,
	erfc = true,
	besselj = true,
	bessely = true,
}

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

function ScriptBuilder:add_apply_helper()
	table.insert(self.lines, APPLY_HELPER)
	table.insert(self.lines, MATRIX_PATCH)
	return self
end

function ScriptBuilder:declare_variables(variables, functions, use_positive_symbols)
	if variables and #variables > 0 then
		for _, var in ipairs(variables) do
			if use_positive_symbols then
				table.insert(self.lines, ("%s = sp.Symbol('%s', real=True, positive=True)"):format(var, var))
			else
				table.insert(self.lines, ("%s = sp.Symbol('%s')"):format(var, var))
			end
		end
	end

	if functions then
		local func_names = {}
		for k in pairs(functions) do
			table.insert(func_names, k)
		end
		table.sort(func_names)

		for _, name in ipairs(func_names) do
			local indep_vars_set = functions[name]
			local indep_list = {}
			for v in pairs(indep_vars_set) do
				table.insert(indep_list, v)
			end
			table.sort(indep_list)

			local args_str = table.concat(indep_list, ", ")
			table.insert(self.lines, ("%s = sp.Function('%s')(%s)"):format(name, name, args_str))
		end
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

local function get_flat_name(node)
	if not node then
		return nil
	end
	if node.type == "variable" or node.type == "symbol" or node.type == "greek" then
		return node.name
	elseif node.type == "number" then
		return tostring(node.value)
	elseif node.type == "subscript" then
		local base = get_flat_name(node.base)
		local sub = get_flat_name(node.subscript)
		if base and sub then
			return base .. "_" .. sub
		end
	end
	return nil
end

local function find_all_symbols(node)
	local symbols = {}
	local functions = {}
	local has_laplace = false

	local function add_function_dependency(func_name, var_name)
		if BUILTIN_FUNCTIONS[func_name] or BUILTIN_FUNCTIONS[func_name:lower()] then
			return
		end
		if not functions[func_name] then
			functions[func_name] = {}
		end
		if var_name then
			functions[func_name][var_name] = true
		end
	end

	local function traverse(n)
		if type(n) ~= "table" then
			return
		end

		local t = n.type

		if t == "laplace_transform" then
			has_laplace = true
			symbols["t"] = true
			symbols["s"] = true
		elseif t == "inverse_laplace_transform" then
			has_laplace = true
			symbols["s"] = true
			symbols["t"] = true
		elseif t == "convolution" then
			symbols["t"] = true
			symbols["y"] = true
		elseif t == "wronskian" then
			local var_name = get_flat_name(n.variable) or "x"
			symbols[var_name] = true

			if n.functions then
				for _, func_node in ipairs(n.functions) do
					local fname = get_flat_name(func_node)
					if fname then
						add_function_dependency(fname, var_name)
					end
				end
			end
		end

		if t == "ordinary_derivative" then
			if n.expression and n.expression.type == "variable" and n.variable and n.variable.type == "variable" then
				add_function_dependency(n.expression.name, n.variable.name)
			end
			if n.expression and n.expression.type == "function_call" then
				local fname_node = n.expression.name_node
				if fname_node and fname_node.type == "variable" then
					local func_name = fname_node.name
					if n.variable and n.variable.type == "variable" then
						add_function_dependency(func_name, n.variable.name)
					end
				end
			end
		end

		if t == "partial_derivative" then
			local func_name = nil
			if n.expression.type == "variable" then
				func_name = n.expression.name
			elseif n.expression.type == "function_call" and n.expression.name_node then
				func_name = n.expression.name_node.name
			end

			if func_name and n.variables then
				for _, vinfo in ipairs(n.variables) do
					if vinfo.variable and vinfo.variable.name then
						add_function_dependency(func_name, vinfo.variable.name)
					end
				end
			end
		end

		if t == "function_call" and n.name_node and (n.name_node.type == "variable" or n.name_node.type == "greek") then
			local func_name = n.name_node.name
			if not BUILTIN_FUNCTIONS[func_name] and not BUILTIN_FUNCTIONS[func_name:lower()] then
				if n.args then
					local found_arg = false
					for _, arg in ipairs(n.args) do
						if arg.type == "variable" then
							add_function_dependency(func_name, arg.name)
							found_arg = true
						end
					end
					if not found_arg and not functions[func_name] then
						functions[func_name] = {}
					end
				else
					if not functions[func_name] then
						functions[func_name] = {}
					end
				end
			end
		end

		if t == "variable" or t == "symbol" or t == "greek" then
			local name = n.name
			if name and not constants.is_constant(name) then
				symbols[name] = true
			end
			return
		end

		for k, v in pairs(n) do
			if k ~= "type" and type(v) == "table" then
				traverse(v)
			end
		end
	end

	traverse(node)

	local result_symbols = {}
	for name in pairs(symbols) do
		if not functions[name] then
			table.insert(result_symbols, name)
		end
	end
	table.sort(result_symbols)

	return result_symbols, functions, has_laplace
end

function M.build_command(code, opts)
	local units_present = false
	local variables = {}
	local functions = {}
	local has_laplace = false

	if opts.ast then
		units_present = ast_utils.has_units(opts.ast)
		variables, functions, has_laplace = find_all_symbols(opts.ast)
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
		:add_apply_helper()
		:declare_variables(variables, functions, has_laplace)
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
	return table.concat(cleaned, "\n"):match("^%s*(.-)%s*$")
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
	local opts = { code = resolved_value, variable_name = name, assignment = true }
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
	return "import sys; sys.ps1=''; sys.ps2=''; import sympy as sp; import sympy.physics.units as u; from sympy import *; "
		.. APPLY_HELPER
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
