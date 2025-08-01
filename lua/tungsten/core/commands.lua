-- core/comands.lua
-- Defines core user-facing Neovim commands
-----------------------------------------------

local parser = require("tungsten.core.parser")
local solver = require("tungsten.core.solver")
local evaluator = require("tungsten.core.engine")
local selection = require("tungsten.util.selection")
local event_bus = require("tungsten.event_bus")
local config = require("tungsten.config")
local logger = require("tungsten.util.logger")
local error_handler = require("tungsten.util.error_handler")
local state = require("tungsten.state")
local string_util = require("tungsten.util.string")
local cmd_utils = require("tungsten.util.commands")
local persistent_vars = require("tungsten.core.persistent_vars")
local ast_creator = require("tungsten.core.ast")
local workflow = require("tungsten.core.workflow")
local definitions = require("tungsten.core.command_definitions")

local function tungsten_evaluate_command(_)
	workflow.run(definitions.TungstenEvaluate)
end

local function tungsten_simplify_command(_)
	workflow.run(definitions.TungstenSimplify)
end

local function tungsten_factor_command(_)
	workflow.run(definitions.TungstenFactor)
end

local function tungsten_toggle_numeric_mode_command(_)
	config.numeric_mode = not config.numeric_mode
	local status = config.numeric_mode and "enabled" or "disabled"
	logger.info("Numeric mode " .. status .. ".")
end

local function tungsten_toggle_debug_mode_command(_)
	config.debug = not config.debug
	if config.debug then
		logger.set_level("DEBUG")
	else
		logger.set_level(config.log_level or "INFO")
	end
	local status = config.debug and "enabled" or "disabled"
	logger.info("Debug mode " .. status .. ".")
end

local function tungsten_status_command(_)
	local status_window = require("tungsten.ui.status_window")
	status_window.open()
	local summary = evaluator.get_active_jobs_summary()
	logger.info("Tungsten", summary)
end

local function tungsten_show_ast_command(_)
	local ast, _, err = cmd_utils.parse_selected_latex("expression")
	if err then
		error_handler.notify_error("AST", err)
		return
	end
	if not ast then
		return
	end

	local formatter = require("tungsten.util.ast_format")
	local float = require("tungsten.ui.float_result")
	float.show(formatter.format(ast))
end

local function define_persistent_variable_command(_)
	local selection_text = selection.get_visual_selection()
	local name, rhs, parse_err = persistent_vars.parse_definition(selection_text)
	if parse_err then
		error_handler.notify_error("DefineVar", parse_err)
	end

	logger.debug("Tungsten Debug", "Defining variables '" .. name .. "' with LaTeX RHS: '" .. rhs .. "'")

	local backend_def, conversion_err = persistent_vars.latex_to_backend_code(name, rhs)
	if conversion_err then
		error_handler.notify_error("DefineVar", conversion_err)
		return
	end

	logger.debug("Tungsten Debug", "Storing variable '" .. name .. "' with string: '" .. backend_def .. "'")

	persistent_vars.store(name, backend_def)

	logger.info("Tungsten", "Defined persistent variable '" .. name .. "' as '" .. backend_def .. "'.")
end

local function tungsten_clear_persistent_vars_command(_)
	state.persistent_variables = {}
	logger.info("Tungsten", "Persistent variables cleared.")
end

local function make_solver_callback(cmd_name, start_mark, end_mark, text, mode)
	return function(result, err)
		if err then
			error_handler.notify_error(cmd_name, err)
			return
		end
		if result == nil or result == "" then
			error_handler.notify_error(cmd_name, "No solution found or an issue occurred.")
			return
		end
		event_bus.emit("result_ready", {
			result = result,
			start_mark = start_mark,
			end_mark = end_mark,
			selection_text = text,
			mode = mode,
			separator = " \\rightarrow ",
		})
	end
end

local function tungsten_solve_command(_)
	local _, start_mark, end_mark, mode = selection.create_selection_extmarks()

	local parsed_ast_top, equation_text, parse_err = cmd_utils.parse_selected_latex("equation")
	if parse_err then
		error_handler.notify_error("Solve", parse_err)
		return
	end
	if not parsed_ast_top then
		return
	end

	local eq_ast
	if parsed_ast_top.type == "solve_system_equations_capture" then
		if parsed_ast_top.equations and #parsed_ast_top.equations == 1 then
			eq_ast = parsed_ast_top.equations[1]
			logger.debug("Tungsten Debug", "TungstenSolve: Extracted single equation from system capture.")
		else
			error_handler.notify_error("Solve", "Parsed as system with not exactly one equation.")
			return
		end
	else
		eq_ast = parsed_ast_top
	end

	local valid_structure = eq_ast
		and (
			(eq_ast.type == "binary" and eq_ast.operator == "=")
			or eq_ast.type == "EquationRule"
			or eq_ast.type == "equation"
		)

	if not valid_structure then
		error_handler.notify_error("Solve", "Selected text is not a valid single equation.")
		return
	end

	vim.ui.input({ prompt = "Enter variable to solve for (e.g., x):" }, function(var_input)
		if not var_input or var_input == "" then
			error_handler.notify_error("Solve", "No variable entered.")
			return
		end
		local trimmed = string_util.trim(var_input)
		if trimmed == "" then
			error_handler.notify_error("Solve", "Variable cannot be empty.")
			return
		end

		local ok, var_ast = pcall(parser.parse, trimmed)
		if not ok or not var_ast or var_ast.type ~= "variable" then
			error_handler.notify_error("Solve", "Invalid variable: '" .. trimmed .. "'. " .. tostring(var_ast or ""))
			return
		end

		solver.solve_asts_async(
			{ eq_ast },
			{ var_ast },
			false,
			make_solver_callback("Solve", start_mark, end_mark, equation_text, mode)
		)
	end)
end

local function tungsten_solve_system_command(_)
	local _, start_mark, end_mark, mode = selection.create_selection_extmarks()

	local capture_ast, selection_text, parse_err = cmd_utils.parse_selected_latex("system of equations")
	if parse_err then
		error_handler.notify_error("SolveSystem", parse_err)
		return
	end
	if not capture_ast then
		return
	end

	if capture_ast.type ~= "solve_system_equations_capture" then
		error_handler.notify_error("SolveSystem", "Selected text does not form a valid system of equations.")
		return
	end

	local equations = capture_ast.equations

	vim.ui.input({ prompt = "Enter variables (e.g., x, y or x; y):" }, function(input_vars_str)
		if not input_vars_str or input_vars_str:match("^%s*$") then
			error_handler.notify_error("SolveSystem", "No variables entered.")
			return
		end

		local var_names = input_vars_str:find(";") and vim.split(input_vars_str, ";%s*")
			or vim.split(input_vars_str, ",%s*")
		local var_asts = {}
		for _, name in ipairs(var_names) do
			local trimmed = name:match("^%s*(.-)%s*$")
			if trimmed ~= "" then
				table.insert(var_asts, ast_creator.create_variable_node(trimmed))
			end
		end

		if #var_asts == 0 then
			error_handler.notify_error("SolveSystem", "No valid variables parsed from input.")
			return
		end

		solver.solve_asts_async(
			equations,
			var_asts,
			true,
			make_solver_callback("SolveSystem", start_mark, end_mark, selection_text, mode)
		)
	end)
end

local registry = require("tungsten.core.registry")

local M = {
	tungsten_evaluate_command = tungsten_evaluate_command,
	tungsten_simplify_command = tungsten_simplify_command,
	tungsten_factor_command = tungsten_factor_command,
	define_persistent_variable_command = define_persistent_variable_command,
	tungsten_solve_command = tungsten_solve_command,
	tungsten_solve_system_command = tungsten_solve_system_command,
	tungsten_toggle_numeric_mode_command = tungsten_toggle_numeric_mode_command,
	tungsten_toggle_debug_mode_command = tungsten_toggle_debug_mode_command,
	tungsten_clear_persistent_vars_command = tungsten_clear_persistent_vars_command,
	tungsten_status_command = tungsten_status_command,
	tungsten_show_ast_command = tungsten_show_ast_command,
}

M.commands = {
	{
		name = "TungstenEvaluate",
		func = tungsten_evaluate_command,
		opts = { range = true, desc = "Evaluate selected LaTeX and insert the result" },
	},
	{
		name = "TungstenSimplify",
		func = tungsten_simplify_command,
		opts = { range = true, desc = "Simplify the selected LaTeX expression" },
	},
	{
		name = "TungstenFactor",
		func = tungsten_factor_command,
		opts = { range = true, desc = "Factor the selected LaTeX expression" },
	},
	{
		name = "TungstenDefinePersistentVariable",
		func = define_persistent_variable_command,
		opts = { range = true, desc = "Define a persistent variable from the selected LaTeX assignment (e.g., x = 1+1)" },
	},
	{
		name = "TungstenClearCache",
		func = function()
			evaluator.clear_cache()
		end,
		opts = { desc = "Clear the Tungsten evaluation cache" },
	},
	{
		name = "TungstenClearPersistentVars",
		func = tungsten_clear_persistent_vars_command,
		opts = { desc = "Clear Tungsten persistent variables" },
	},
	{
		name = "TungstenViewActiveJobs",
		func = function()
			evaluator.view_active_jobs()
		end,
		opts = { desc = "View active Tungsten evaluation jobs" },
	},
	{
		name = "TungstenToggleNumericMode",
		func = tungsten_toggle_numeric_mode_command,
		opts = { desc = "Toggle Tungsten numeric mode" },
	},
	{
		name = "TungstenToggleDebugMode",
		func = tungsten_toggle_debug_mode_command,
		opts = { desc = "Toggle Tungsten debug mode" },
	},
	{
		name = "TungstenSolve",
		func = tungsten_solve_command,
		opts = { range = true, desc = "Solve the selected equation for the specified variable (e.g., 'x+y=z; x')" },
	},
	{
		name = "TungstenSolveSystem",
		func = tungsten_solve_system_command,
		opts = { range = true, desc = "Solve a system of visually selected LaTeX equations for specified variables" },
	},
	{
		name = "TungstenStatus",
		func = tungsten_status_command,
		opts = { desc = "Show Tungsten job status" },
	},
	{
		name = "TungstenShowAST",
		func = tungsten_show_ast_command,
		opts = { range = true, desc = "Display AST of selected expression" },
	},
}

for _, cmd in ipairs(M.commands) do
	registry.register_command(cmd)
end

return M
