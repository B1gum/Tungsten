local evaluator = require("tungsten.core.engine")
local config = require("tungsten.config")
local cmd_utils = require("tungsten.util.commands")
local ast_creator = require("tungsten.core.ast")

local M = {}

M.TungstenEvaluate = {
	description = "Evaluate",
	input_handler = function()
		return cmd_utils.parse_selected_latex("expression")
	end,
	task_handler = function(ast, numeric_mode, callback)
		evaluator.evaluate_async(ast, numeric_mode, callback)
	end,
	prepare_args = function(ast, _)
		return { ast, config.numeric_mode }
	end,
}

local function make_simple_wrapped(name)
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
	}
end

M.TungstenSimplify = make_simple_wrapped("Simplify")
M.TungstenFactor = make_simple_wrapped("Factor")

return M
