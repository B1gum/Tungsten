-- tests/unit/domains/differential_equations/commands_spec.lua

local spy = require("luassert.spy")
local match = require("luassert.match")

describe("Tungsten Differential Equations Commands", function()
	local de_commands

	local mock_selection
	local mock_logger
	local mock_parser
	local mock_evaluator
	local mock_event_bus
	local mock_config
	local mock_ast

	local original_require

	local modules_to_clear_from_cache = {
		"tungsten.domains.differential_equations.commands",
		"tungsten.domains.differential_equations.command_definitions",
		"tungsten.core.workflow",
		"tungsten.util.selection",
		"tungsten.util.commands",
		"tungsten.core.parser",
		"tungsten.core.engine",
		"tungsten.event_bus",
	}

	local current_selection_text
	local current_parsed_ast
	local current_eval_result

	before_each(function()
		mock_selection = {}
		mock_logger = { levels = { ERROR = 1, WARN = 2 } }
		mock_parser = {}
		mock_evaluator = {}
		mock_event_bus = {}
		mock_config = { numeric_mode = false }
		mock_ast = {}

		current_selection_text = ""
		current_parsed_ast = nil
		current_eval_result = "evaluated_result"

		mock_selection.get_visual_selection = spy.new(function()
			return current_selection_text
		end)
		mock_selection.create_selection_extmarks = function()
			return 0, 1, 2, "v"
		end
		mock_logger.notify = spy.new(function() end)
		mock_parser.parse = spy.new(function()
			return { series = { current_parsed_ast } }
		end)
		mock_evaluator.evaluate_async = spy.new(function(_, _, cb)
			cb(current_eval_result, nil)
		end)
		mock_event_bus.emit = spy.new(function() end)

		mock_ast.create_ode_node = spy.new(function(lhs, rhs)
			return { type = "ode", lhs = lhs, rhs = rhs }
		end)
		mock_ast.create_ode_system_node = spy.new(function(odes)
			return { type = "ode_system", equations = odes }
		end)
		mock_ast.create_laplace_transform_node = spy.new(function(ast)
			return { type = "laplace_transform", expression = ast }
		end)
		mock_ast.create_inverse_laplace_transform_node = spy.new(function(ast)
			return { type = "inverse_laplace_transform", expression = ast }
		end)

		original_require = _G.require
		_G.require = function(module_path)
			if module_path == "tungsten.util.selection" then
				return mock_selection
			end
			if module_path == "tungsten.util.logger" then
				return mock_logger
			end
			if module_path == "tungsten.core.parser" then
				return mock_parser
			end
			if module_path == "tungsten.core.engine" then
				return mock_evaluator
			end
			if module_path == "tungsten.event_bus" then
				return mock_event_bus
			end
			if module_path == "tungsten.config" then
				return mock_config
			end
			if module_path == "tungsten.core.ast" then
				return mock_ast
			end
			return original_require(module_path)
		end

		require("tests.helpers.mock_utils").reset_modules(modules_to_clear_from_cache)
		de_commands = require("tungsten.domains.differential_equations.commands")
	end)

	after_each(function()
		_G.require = original_require
		require("tests.helpers.mock_utils").reset_modules(modules_to_clear_from_cache)
	end)

	local function test_command(command_fn, command_name, selection_text, parsed_ast, final_ast_producer)
		it("should handle " .. command_name, function()
			current_selection_text = selection_text
			current_parsed_ast = parsed_ast

			command_fn()

			assert.spy(mock_selection.get_visual_selection).was.called()
			assert.spy(mock_parser.parse).was.called_with(selection_text, nil)
			local final_ast = final_ast_producer(parsed_ast)
			assert.spy(mock_evaluator.evaluate_async).was.called_with(final_ast, false, match.is_function())
			assert.spy(mock_event_bus.emit).was.called_with("result_ready", match.is_table())
		end)
	end

	test_command(
		function()
			de_commands.solve_ode_command()
		end,
		":TungstenSolveODE",
		"y' = y",
		{ type = "ode" },
		function(parsed_ast)
			return mock_ast.create_ode_system_node({ parsed_ast })
		end
	)

	test_command(
		function()
			de_commands.wronskian_command()
		end,
		":TungstenWronskian",
		"W(f,g)",
		{ type = "wronskian" },
		function(ast)
			return ast
		end
	)

	test_command(
		function()
			de_commands.laplace_command()
		end,
		":TungstenLaplace",
		"f(t)",
		{ type = "function_call" },
		function(ast)
			return mock_ast.create_laplace_transform_node(ast)
		end
	)

	test_command(
		function()
			de_commands.inverse_laplace_command()
		end,
		":TungstenInverseLaplace",
		"F(s)",
		{ type = "function_call" },
		function(ast)
			return mock_ast.create_inverse_laplace_transform_node(ast)
		end
	)

	test_command(
		function()
			de_commands.convolve_command()
		end,
		":TungstenConvolve",
		"f(t) * g(t)",
		{ type = "convolution" },
		function(ast)
			return ast
		end
	)
end)
