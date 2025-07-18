-- lua/tungsten/domains/differential_equations/commands.lua
-- Defines the implementation for user-facing commands in the differential_equations domain.

local selection = require("tungsten.util.selection")
local error_handler = require("tungsten.util.error_handler")
local parser = require("tungsten.core.parser")
local evaluator = require("tungsten.core.engine")
local insert_result_util = require("tungsten.util.insert_result")
local config = require("tungsten.config")
local ast = require("tungsten.core.ast")

local function evaluate_and_insert(command_name, ast_producer)
	local visual_selection_text = selection.get_visual_selection()
	if not visual_selection_text or visual_selection_text == "" then
		error_handler.notify_error(command_name, "No text selected.")
		return
	end

	local parse_ok, parsed_ast, err_msg = pcall(parser.parse, visual_selection_text)
	if not parse_ok or not parsed_ast then
		error_handler.notify_error(command_name, err_msg or "Parse error")
		return
	end

	local final_ast = ast_producer(parsed_ast)
	if not final_ast then
		error_handler.notify_error(command_name, "Could not create a valid AST from selection.")
		return
	end

	evaluator.evaluate_async(final_ast, config.numeric_mode, function(result, err)
		if err then
			error_handler.notify_error(command_name, "Error during evaluation: " .. tostring(err))
			return
		end
		if result == nil or result == "" then
			error_handler.notify_error(command_name, "No result from evaluation.")
			return
		end
		insert_result_util.insert_result(result, " \\rightarrow ")
	end)
end

local function solve_ode_command()
	evaluate_and_insert("TungstenSolveODE", function(parsed_ast)
		if parsed_ast.type == "ode" then
			return ast.create_ode_system_node({ parsed_ast })
		elseif parsed_ast.type == "binary" and parsed_ast.operator == "=" then
			local ode_node = ast.create_ode_node(parsed_ast.left, parsed_ast.right)
			return ast.create_ode_system_node({ ode_node })
		end

		return parsed_ast
	end)
end

local function wronskian_command()
	evaluate_and_insert("TungstenWronskian", function(parsed_ast)
		return parsed_ast
	end)
end

local function laplace_command()
	evaluate_and_insert("TungstenLaplace", function(parsed_ast)
		return ast.create_laplace_transform_node(parsed_ast)
	end)
end

local function inverse_laplace_command()
	evaluate_and_insert("TungstenInverseLaplace", function(parsed_ast)
		return ast.create_inverse_laplace_transform_node(parsed_ast)
	end)
end

local function convolve_command()
	evaluate_and_insert("TungstenConvolve", function(parsed_ast)
		return parsed_ast
	end)
end

local M = {
	solve_ode_command = solve_ode_command,
	wronskian_command = wronskian_command,
	laplace_command = laplace_command,
	inverse_laplace_command = inverse_laplace_command,
	convolve_command = convolve_command,
}

M.commands = {
	{
		name = "TungstenSolveODE",
		func = solve_ode_command,
		opts = { range = true, desc = "Solve the selected ODE or ODE system" },
	},
	{
		name = "TungstenSolveODESystem",
		func = solve_ode_command,
		opts = { range = true, desc = "Solve the selected ODE system (alias for TungstenSolveODE)" },
	},
	{
		name = "TungstenWronskian",
		func = wronskian_command,
		opts = { range = true, desc = "Calculate the Wronskian of the selected functions" },
	},
	{
		name = "TungstenLaplace",
		func = laplace_command,
		opts = { range = true, desc = "Calculate the Laplace transform of the selected function" },
	},
	{
		name = "TungstenInverseLaplace",
		func = inverse_laplace_command,
		opts = { range = true, desc = "Calculate the inverse Laplace transform of the selected function" },
	},
	{
		name = "TungstenConvolve",
		func = convolve_command,
		opts = { range = true, desc = "Calculate the convolution of the two selected functions" },
	},
}

return M
