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
M.TungstenCollect = {
	description = "Collect expression by powers",
	input_handler = function()
		return cmd_utils.parse_selected_latex("expression")
	end,
	task_handler = function(ast, collect_variable, numeric_mode, cb)
		local call = ast_creator.create_function_call_node(ast_creator.create_variable_node("Collect"), {
			ast,
			collect_variable,
			ast_creator.create_variable_node("Simplify"),
		})
		local state = require("tungsten.state")
		-- if we use wolfram, then we also sort by powers
		if (state.active_backend or config.backend or "wolfram") == "wolfram" then
			local function fn(name, args)
				return ast_creator.create_function_call_node(ast_creator.create_variable_node(name), args)
			end
			-- convert the collected expression to numeric form if it is specified
			local polynomial = numeric_mode and fn("N", { call }) or call
			-- create monomial list: {x^n a, x^(n-1) b, etc.}
			local monomials = fn("MonomialList", { polynomial, fn("List", { collect_variable }) })
			-- the monomials are List[...]
			-- Apply replaces List with Plus
			-- Hold Form prevents wolfram from reorganizing the terms
			call = fn("Apply", {
				ast_creator.create_variable_node("Plus"),
				fn("HoldForm", {
					fn("Evaluate", { monomials }),
				}),
				fn("List", { ast_creator.create_number_node(1) }),
			})
		end
		evaluator.evaluate_async(call, numeric_mode, cb)
	end,
	prepare_args = function(ast, _, opts)
		return {
			ast,
			opts.collect_variable,
			config.numeric_mode,
		}
	end,
	separator = " \\rightarrow ",
}

M.TungstenTogglePersistence = {
	description = "Toggle persistent engine session",
	task_handler = function()
		local state = require("tungsten.state")
		local backend_name = state.active_backend

		if not backend_name or not config.backend_opts[backend_name] then
			logger.warn("Tungsten", "No active wolfram-backend configuration found to toggle persistence.")
			return
		end

		local current_val = config.backend_opts[backend_name].persistent or false
		config.backend_opts[backend_name].persistent = not current_val

		local new_status = config.backend_opts[backend_name].persistent
		if not new_status then
			require("tungsten.core.engine").stop_persistent_session()
		end

		local status = new_status and "Enabled" or "Disabled"
		logger.info("Tungsten", "Persistent session " .. status .. " for " .. backend_name)
	end,
}

return M
