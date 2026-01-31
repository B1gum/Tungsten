local evaluator = require("tungsten.core.engine")
local config = require("tungsten.config")
local cmd_utils = require("tungsten.util.commands")
local ast_creator = require("tungsten.core.ast")
local selection = require("tungsten.util.selection")
local parser = require("tungsten.core.parser")
local persistent_vars = require("tungsten.core.persistent_vars")
local error_handler = require("tungsten.util.error_handler")
local logger = require("tungsten.util.logger")

local M = {}

local function parse_evaluate_selection()
	local text = selection.get_visual_selection()
	if not text or text == "" then
		return nil, nil, "No expression selected."
	end

	local assignment_name
	local rhs_text = text
	local operator = config.persistent_variable_assignment_operator

	if operator and text:find(operator, 1, true) then
		assignment_name, rhs_text = persistent_vars.parse_definition(text)
		if not assignment_name then
			return nil, nil, rhs_text or "Invalid assignment syntax."
		end
	end

	local ok, parsed, err_msg = pcall(parser.parse, rhs_text, nil)
	if not ok or not parsed then
		return nil, text, err_msg or tostring(parsed)
	end
	if not parsed.series or #parsed.series ~= 1 then
		return nil, text, "Selection must contain a single expression"
	end

	local ast = parsed.series[1]
	if assignment_name then
		ast._persistent_assignment = { name = assignment_name, rhs_text = rhs_text }
	end

	return ast, text, nil
end

M.TungstenEvaluate = {
	description = "Evaluate",
	input_handler = parse_evaluate_selection,
	task_handler = function(ast, numeric_mode, assignment_info, callback)
		local function handle_result(result, err)
			if not err and assignment_info and result and result ~= "" then
				local backend_def, conversion_err = persistent_vars.latex_to_backend_code(assignment_info.name, result)
				if conversion_err then
					error_handler.notify_error("PersistentVarAssign", conversion_err)
				elseif backend_def then
					persistent_vars.store(assignment_info.name, backend_def)
					logger.info(
						"Tungsten",
						"Defined persistent variable '" .. assignment_info.name .. "' as '" .. backend_def .. "'."
					)
				end
			end

			callback(result, err)
		end

		evaluator.evaluate_async(ast, numeric_mode, handle_result)
	end,
	prepare_args = function(ast, _)
		return { ast, config.numeric_mode, ast._persistent_assignment or false }
	end,
}

local function make_simple_wrapped(name, separator)
	return {
		description = name,
		input_handler = function()
			return cmd_utils.parse_selected_latex("expression")
		end,
		task_handler = function(ast, numeric_mode, cb)
			evaluator.evaluate_async(
				ast_creator.create_function_call_node(ast_creator.create_variable_node(name), { ast }),
				numeric_mode,
				cb
			)
		end,
		prepare_args = function(ast, _)
			return { ast, config.numeric_mode }
		end,
		separator = separator,
	}
end

M.TungstenSimplify = make_simple_wrapped("Simplify", " \\rightarrow ")
M.TungstenFactor = make_simple_wrapped("Factor", " \\rightarrow ")

M.TungstenTogglePersistence = {
	description = "Toggle persistent engine session",
	task_handler = function()
		config.persistent = not config.persistent
		if not config.persistent then
			require("tungsten.core.engine").stop_persistent_session()
		end
		local status = config.persistent and "Enabled" or "Disabled"
		logger.info("Tungsten", "Persistent session " .. status)
	end,
}

return M
