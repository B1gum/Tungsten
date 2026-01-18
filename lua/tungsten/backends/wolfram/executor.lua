-- lua/tungsten/backends/wolfram/executor.lua
-- Provides function to convert AST to wolfram code and execute it

local render = require("tungsten.core.render")
local config = require("tungsten.config")
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

local function is_unit_convert_call(node)
	if type(node) ~= "table" then
		return false
	end
	if node.type ~= "function_call" then
		return false
	end
	local name_node = node.name_node
	return name_node and name_node.name == "UnitConvert"
end

local function prepare_wolfram_code(raw_code, opts, has_units_flag)
	opts = opts or {}
	local code = raw_code
	local form = opts.form

	if config.numeric_mode or opts.numeric then
		code = "N[" .. code .. "]"
	end

	if has_units_flag and not opts.is_unit_convert then
		code = "Quiet[UnitSimplify[" .. code .. "]]"
		if not form then
			form = "InputForm"
		end
	end
	if opts.is_unit_convert and not form then
		form = "InputForm"
	end

	if not form then
		form = "TeXForm"
	end

	if form == "InputForm" then
		code = "ToString[" .. code .. ', CharacterEncoding -> "UTF8", FormatType -> InputForm]'
	else
		code = "ToString[TeXForm[" .. code .. '], CharacterEncoding -> "UTF8"]'
	end

	return code, form
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
		units_present = has_units(opts.ast)
	end

	local is_unit_convert = is_unit_convert_call(opts.ast)
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

function M.prepare_solve_opts()
	return { form = "TeXForm" }
end

function M.exit_error(exit_code)
	return ("WolframScript exited with code %d"):format(exit_code)
end

function M.evaluate_async(ast, opts, callback)
	return base_executor.evaluate_async(M, ast, opts, callback)
end

function M.solve_async(solve_ast, opts, callback)
	return base_executor.solve_async(M, solve_ast, opts, callback)
end

return M
