-- lua/tungsten/backends/wolfram/executor.lua
-- Provides function to convert AST to wolfram code and execute it

local config = require("tungsten.config")
local ast_utils = require("tungsten.core.ast_utils")
local base_executor = require("tungsten.backends.base_executor")
local handlers = require("tungsten.backends.wolfram.handlers")
local solution_parser = require("tungsten.backends.wolfram.wolfram_solution")

local M = {}
M.display_name = "Wolfram"
M.not_found_message = "WolframScript not found. Check wolfram_path."

function M.get_interpreter_command()
	local wolfram_opts = (config.backend_opts and config.backend_opts.wolfram) or {}
	return wolfram_opts.wolfram_path or "wolframscript"
end

local function build_wolfram_config(opts, has_units_flag)
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

local function apply_numeric_wrapper(code, build)
	if build.numeric then
		return "N[" .. code .. "]"
	end
	return code
end

local function apply_unit_simplify_wrapper(code, build)
	if build.has_units and not build.is_unit_convert then
		return "Quiet[UnitSimplify[" .. code .. "]]"
	end
	return code
end

local function apply_output_formatter(code, build)
	if build.form == "InputForm" then
		return "ToString[" .. code .. ', CharacterEncoding -> "UTF8", FormatType -> InputForm]'
	end
	return "ToString[TeXForm[" .. code .. '], CharacterEncoding -> "UTF8"]'
end

local function prepare_wolfram_code(raw_code, opts, has_units_flag)
	local build = build_wolfram_config(opts, has_units_flag)
	local code = raw_code

	code = apply_numeric_wrapper(code, build)
	code = apply_unit_simplify_wrapper(code, build)
	code = apply_output_formatter(code, build)

	return code, build.form
end

local function sanitize_wolfram_output(stdout, form_type)
	local result = stdout

	result = result:gsub('Interpreting unit ".-"%.+\n*', "")
	result = result:gsub("\\theta", "u") -- Use u for the heaviside step function instead of theta

	if form_type == "InputForm" then
		local format_quantities = solution_parser.format_quantities or function(x)
			return x
		end
		result = format_quantities(result)
	end

	return result
end

function M.build_command(raw_code, opts)
	local units_present = false
	if opts.ast then
		units_present = ast_utils.has_units(opts.ast)
	end

	local is_unit_convert = ast_utils.is_unit_convert_call(opts.ast)
	local code, form = prepare_wolfram_code(raw_code, {
		numeric = opts.numeric,
		form = opts.form,
		is_unit_convert = is_unit_convert,
	}, units_present)

	return { "-code", code }, { form = form }
end

function M.sanitize_output(stdout, ctx)
	return sanitize_wolfram_output(stdout, ctx and ctx.form)
end

function M.parse_solution(result, variables, opts)
	return solution_parser.parse_wolfram_solution(result, variables, opts.is_system)
end

function M.ast_to_code(ast)
	return base_executor.ast_to_code(M, ast, {
		ensure_handlers = handlers.ensure_handlers,
		handlers_label = M.display_name,
	})
end

function M.prepare_solve_opts()
	return { form = "TeXForm" }
end

function M.exit_error(exit_code)
	return ("WolframScript exited with code %d"):format(exit_code)
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
	return { cmd }
end

function M.get_persistent_init()
	return "Null"
end

function M.sanitize_persistent_output(output)
	if not output then
		return ""
	end
	output = output:gsub("In%[%d+%]:=%s*", "")
	output = output:gsub("Out%[%d+%]=%s*", "")
	return output:match("^%s*(.-)%s*$")
end

function M.format_persistent_input(code, delimiter, opts)
	local numeric = config.numeric_mode or (opts and opts.numeric)
	local final_code = code

	if numeric then
		final_code = "N[" .. code .. "]"
	end

	return string.format(
		'\nPrint[ToString[TeXForm[Quiet[%s]], CharacterEncoding -> "UTF8"]]; Print["%s"];',
		final_code,
		delimiter
	)
end

return M
