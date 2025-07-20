-- tungsten/tests/unit/core/commands_spec.lua

local spy = require("luassert.spy")
local vim_test_env = require("tests.helpers.vim_test_env")
local match = require("luassert.match")
local mock_utils = require("tests.helpers.mock_utils")

describe("Tungsten core commands", function()
	local commands_module

	local mock_evaluator_evaluate_async_spy
	local mock_insert_result_insert_result_spy
	local mock_logger_notify_spy
	local mock_solver_solve_equation_async_spy
	local mock_cmd_utils_parse_selected_latex_spy

	local mock_evaluator_module
	local mock_insert_result_util_module
	local mock_logger_module
	local mock_solver_module
	local mock_config_module
	local mock_cmd_utils_module
	local mock_state_module
	local mock_wolfram_backend_module

	local original_require

	local current_parse_selected_latex_config
	local current_eval_async_config_key
	local current_solve_equation_config

	local eval_async_behaviors = {}

	local modules_to_clear_from_cache = {
		"tungsten.core.commands",
		"tungsten.core.engine",
		"tungsten.core.solver",
		"tungsten.util.insert_result",
		"tungsten.config",
		"tungsten.util.logger",
		"tungsten.util.commands",
		"tungsten.state",
		"tungsten.backends.wolfram",
	}

	before_each(function()
		vim_test_env.setup_buffer({ "line1", "line2" })
		_G.vim.fn = _G.vim.fn or {}
		_G.vim.fn.mode = function()
			return "v"
		end
		mock_selection_module = {
			create_selection_extmarks = function()
				return 0, 1, 2, "v"
			end,
		}
		mock_config_module = {
			numeric_mode = false,
			debug = false,
			persistent_variable_assignment_operator = ":=",
			log_level = "INFO",
		}
		mock_evaluator_module = {}
		mock_insert_result_util_module = {}
		mock_logger_module = {}
		mock_solver_module = {}
		mock_cmd_utils_module = {}
		mock_state_module = { persistent_variables = {} }
		mock_wolfram_backend_module = {}

		original_require = _G.require
		_G.require = function(module_path)
			if module_path == "tungsten.config" then
				return mock_config_module
			end
			if module_path == "tungsten.core.engine" then
				return mock_evaluator_module
			end
			if module_path == "tungsten.util.insert_result" then
				return mock_insert_result_util_module
			end
			if module_path == "tungsten.util.selection" then
				return mock_selection_module
			end
			if module_path == "tungsten.util.logger" then
				return mock_logger_module
			end
			if module_path == "tungsten.core.solver" then
				return mock_solver_module
			end
			if module_path == "tungsten.util.commands" then
				return mock_cmd_utils_module
			end
			if module_path == "tungsten.state" then
				return mock_state_module
			end
			if module_path == "tungsten.backends.wolfram" then
				return mock_wolfram_backend_module
			end

			if package.loaded[module_path] then
				return package.loaded[module_path]
			end
			return original_require(module_path)
		end

		mock_utils.reset_modules(modules_to_clear_from_cache)

		vim_test_env.set_plugin_config({ "numeric_mode" }, false)

		current_parse_selected_latex_config = {}
		current_eval_async_config_key = "default_eval"
		current_solve_equation_config = { result = "default_solution", err = nil }

		mock_cmd_utils_parse_selected_latex_spy = spy.new(function(desc)
			local config = current_parse_selected_latex_config[desc]
			if config then
				return config.ast, config.text
			end
			return nil, ""
		end)
		mock_cmd_utils_module.parse_selected_latex = mock_cmd_utils_parse_selected_latex_spy

		eval_async_behaviors.default_eval = function(ast, numeric_mode, callback)
			if ast and ast.representation == "parsed:\\frac{1+1}{2}" then
				callback("1")
			else
				callback(nil)
			end
		end
		eval_async_behaviors.numeric_eval = function(ast, numeric_mode, callback)
			if ast and ast.representation == "parsed:\\frac{1+1}{2}" then
				callback("1.0")
			else
				callback(nil)
			end
		end
		eval_async_behaviors.nil_eval = function(_, _, callback)
			callback(nil)
		end
		eval_async_behaviors.empty_string_eval = function(_, _, callback)
			callback("")
		end

		mock_evaluator_evaluate_async_spy = spy.new(function(ast, numeric_mode, callback)
			local behavior_func = eval_async_behaviors[current_eval_async_config_key]
			if behavior_func then
				behavior_func(ast, numeric_mode, callback)
			else
				error("Unknown current_eval_async_config_key: " .. tostring(current_eval_async_config_key))
			end
		end)
		mock_evaluator_module.evaluate_async = mock_evaluator_evaluate_async_spy

		mock_insert_result_insert_result_spy = spy.new(function(_) end)
		mock_insert_result_util_module.insert_result = mock_insert_result_insert_result_spy

		mock_logger_notify_spy = spy.new(function() end)
		mock_logger_module.notify = mock_logger_notify_spy
		mock_logger_module.levels = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 }
		mock_logger_module.set_level = spy.new(function() end)
		mock_logger_module.debug = function(title, msg)
			mock_logger_notify_spy(msg, mock_logger_module.levels.DEBUG, { title = title })
		end
		mock_logger_module.info = function(title, msg)
			mock_logger_notify_spy(msg, mock_logger_module.levels.INFO, { title = title })
		end
		mock_logger_module.warn = function(title, msg)
			mock_logger_notify_spy(msg, mock_logger_module.levels.WARN, { title = title })
		end
		mock_logger_module.error = function(title, msg)
			mock_logger_notify_spy(msg, mock_logger_module.levels.ERROR, { title = title })
		end

		mock_solver_solve_equation_async_spy = spy.new(function(eqs, vars, is_system, callback)
			callback(current_solve_equation_config.result, current_solve_equation_config.err)
		end)
		mock_solver_module.solve_equation_async = mock_solver_solve_equation_async_spy

		mock_wolfram_backend_module.ast_to_wolfram = spy.new(function(ast)
			return "wolfram(" .. (ast.name or ast.id) .. ")"
		end)

		commands_module = require("tungsten.core.commands")
	end)

	after_each(function()
		_G.require = original_require
		vim_test_env.cleanup()
		mock_utils.reset_modules(modules_to_clear_from_cache)
	end)

	describe(":TungstenEvaluate", function()
		it("should process visual selection, parse, evaluate, and insert result", function()
			current_parse_selected_latex_config["expression"] = {
				ast = { type = "expression", representation = "parsed:\\frac{1+1}{2}" },
				text = "\\frac{1+1}{2}",
			}
			current_eval_async_config_key = "default_eval"

			vim_test_env.set_visual_selection(1, 1, 1, 5)

			commands_module.tungsten_evaluate_command({})

			assert.spy(mock_cmd_utils_parse_selected_latex_spy).was.called_with("expression")
			assert.spy(mock_evaluator_evaluate_async_spy).was.called(1)
			local ast_arg = mock_evaluator_evaluate_async_spy.calls[1].vals[1]
			assert.are.same({ type = "expression", representation = "parsed:\\frac{1+1}{2}" }, ast_arg)
			assert
				.spy(mock_insert_result_insert_result_spy).was
				.called_with("1", nil, match.is_number(), match.is_number(), "\\frac{1+1}{2}", match.is_string())
		end)

		it("should not proceed if parsing fails (cmd_utils returns nil)", function()
			current_parse_selected_latex_config["expression"] = { ast = nil, text = "" }
			vim_test_env.set_visual_selection(1, 1, 1, 1)

			commands_module.tungsten_evaluate_command({})

			assert.spy(mock_cmd_utils_parse_selected_latex_spy).was.called_with("expression")
			assert.spy(mock_evaluator_evaluate_async_spy).was_not.called()
			assert.spy(mock_insert_result_insert_result_spy).was_not.called()
		end)

		it("should not call insert_result if evaluation returns nil", function()
			current_parse_selected_latex_config["expression"] = { ast = { type = "expression" } }
			current_eval_async_config_key = "nil_eval"
			vim_test_env.set_visual_selection(1, 1, 1, 1)
			commands_module.tungsten_evaluate_command({})
			assert.spy(mock_insert_result_insert_result_spy).was_not.called()
		end)

		it("should not call insert_result if evaluation returns empty string", function()
			current_parse_selected_latex_config["expression"] = { ast = { type = "expression" } }
			current_eval_async_config_key = "empty_string_eval"
			vim_test_env.set_visual_selection(1, 1, 1, 1)
			commands_module.tungsten_evaluate_command({})
			assert.spy(mock_insert_result_insert_result_spy).was_not.called()
		end)

		it("should use numeric_mode from config when calling evaluate_async", function()
			vim_test_env.set_plugin_config({ "numeric_mode" }, true)
			current_parse_selected_latex_config["expression"] =
				{ ast = { type = "expression", representation = "parsed:\\frac{1+1}{2}" } }
			current_eval_async_config_key = "numeric_eval"

			vim_test_env.set_visual_selection(1, 1, 1, 5)

			package.loaded["tungsten.core.commands"] = nil
			local temp_commands_module = require("tungsten.core.commands")
			temp_commands_module.tungsten_evaluate_command({})

			assert.spy(mock_evaluator_evaluate_async_spy).was.called(1)
			local numeric_mode_arg = mock_evaluator_evaluate_async_spy.calls[1].vals[2]
			assert.is_true(numeric_mode_arg)
			assert
				.spy(mock_insert_result_insert_result_spy).was
				.called_with("1.0", nil, match.is_number(), match.is_number(), nil, match.is_string())

			vim_test_env.set_plugin_config({ "numeric_mode" }, false)
		end)
	end)

	describe(":TungstenSimplify", function()
		it("wraps selection with Simplify and evaluates", function()
			current_parse_selected_latex_config["expression"] = {
				ast = { type = "expression", representation = "parsed:\\frac{1+1}{2}" },
				text = "\\frac{1+1}{2}",
			}
			eval_async_behaviors.default_eval = function(_, _, cb)
				cb("simp")
			end
			current_eval_async_config_key = "default_eval"

			vim_test_env.set_visual_selection(1, 1, 1, 5)

			commands_module.tungsten_simplify_command({})

			assert.spy(mock_cmd_utils_parse_selected_latex_spy).was.called_with("expression")
			assert.spy(mock_evaluator_evaluate_async_spy).was.called(1)
			local ast_arg = mock_evaluator_evaluate_async_spy.calls[1].vals[1]
			assert.are.equal("function_call", ast_arg.type)
			assert.are.equal("Simplify", ast_arg.name_node.name)
			assert.are.same({ type = "expression", representation = "parsed:\\frac{1+1}{2}" }, ast_arg.args[1])
			assert.spy(mock_insert_result_insert_result_spy).was.called(1)
		end)

		it("does nothing on parse failure", function()
			current_parse_selected_latex_config["expression"] = { ast = nil, text = "" }
			vim_test_env.set_visual_selection(1, 1, 1, 1)

			commands_module.tungsten_simplify_command({})

			assert.spy(mock_evaluator_evaluate_async_spy).was_not.called()
			assert.spy(mock_insert_result_insert_result_spy).was_not.called()
		end)

		it("does not insert result when evaluation returns nil", function()
			current_parse_selected_latex_config["expression"] = { ast = { type = "expression" } }
			current_eval_async_config_key = "nil_eval"
			vim_test_env.set_visual_selection(1, 1, 1, 1)

			commands_module.tungsten_simplify_command({})

			assert.spy(mock_insert_result_insert_result_spy).was_not.called()
		end)
	end)

	describe(":TungstenFactor", function()
		it("wraps selection with Factor and evaluates", function()
			current_parse_selected_latex_config["expression"] = {
				ast = { type = "expression", representation = "parsed:\\frac{1+1}{2}" },
				text = "\\frac{1+1}{2}",
			}
			eval_async_behaviors.default_eval = function(_, _, cb)
				cb("fact")
			end
			current_eval_async_config_key = "default_eval"

			vim_test_env.set_visual_selection(1, 1, 1, 5)

			commands_module.tungsten_factor_command({})

			assert.spy(mock_cmd_utils_parse_selected_latex_spy).was.called_with("expression")
			assert.spy(mock_evaluator_evaluate_async_spy).was.called(1)
			local ast_arg = mock_evaluator_evaluate_async_spy.calls[1].vals[1]
			assert.are.equal("function_call", ast_arg.type)
			assert.are.equal("Factor", ast_arg.name_node.name)
			assert.are.same({ type = "expression", representation = "parsed:\\frac{1+1}{2}" }, ast_arg.args[1])
			assert.spy(mock_insert_result_insert_result_spy).was.called(1)
		end)

		it("does nothing on parse failure", function()
			current_parse_selected_latex_config["expression"] = { ast = nil, text = "" }
			vim_test_env.set_visual_selection(1, 1, 1, 1)

			commands_module.tungsten_factor_command({})

			assert.spy(mock_evaluator_evaluate_async_spy).was_not.called()
			assert.spy(mock_insert_result_insert_result_spy).was_not.called()
		end)

		it("does not insert result when evaluation returns nil", function()
			current_parse_selected_latex_config["expression"] = { ast = { type = "expression" } }
			current_eval_async_config_key = "nil_eval"
			vim_test_env.set_visual_selection(1, 1, 1, 1)

			commands_module.tungsten_factor_command({})

			assert.spy(mock_insert_result_insert_result_spy).was_not.called()
		end)
	end)

	describe(":TungstenSolve", function()
		local original_ui_input

		before_each(function()
			vim_test_env.set_visual_selection(1, 1, 1, 15)
			current_parse_selected_latex_config["equation"] = {
				ast = { type = "equation", name = "quadratic_eq" },
				text = "a*x^2+b*x+c=0",
			}
			current_solve_equation_config = { result = "some_solution", err = nil }

			original_ui_input = vim.ui.input
			vim.ui.input = spy.new(function(opts, on_confirm)
				on_confirm("x")
			end)

			package.loaded["tungsten.core.parser"].parse = spy.new(function(text)
				if text == "x" then
					return { type = "variable", name = "x" }
				end
				return nil
			end)
		end)

		after_each(function()
			vim.ui.input = original_ui_input
		end)

		it("should call cmd_utils.parse_selected_latex", function()
			commands_module.tungsten_solve_command({})
			assert.spy(mock_cmd_utils_parse_selected_latex_spy).was.called_with("equation")
		end)

		it("should call solver.solve_equation_async with processed ASTs and a callback", function()
			commands_module.tungsten_solve_command({})
			assert.spy(mock_solver_solve_equation_async_spy).was.called(1)
			local args = mock_solver_solve_equation_async_spy.calls[1].vals
			assert.are.same({ "wolfram(quadratic_eq)" }, args[1])
			assert.are.same({ "wolfram(x)" }, args[2])
			assert.is_false(args[3])
		end)

		it("should call insert_result when solver callback provides a solution", function()
			commands_module.tungsten_solve_command({})
			assert.spy(mock_insert_result_insert_result_spy).was.called(1)
			assert
				.spy(mock_insert_result_insert_result_spy).was
				.called_with("some_solution", " \\rightarrow ", match.is_number(), match.is_number(), "a*x^2+b*x+c=0", match.is_string())
		end)
	end)

	describe(":TungstenSolveSystem", function()
		local mock_vim_ui_input_spy
		local original_vim_ui_input

		before_each(function()
			original_vim_ui_input = vim.ui.input
			mock_vim_ui_input_spy = spy.new(function(opts, on_confirm_callback)
				on_confirm_callback("x,y")
			end)
			vim.ui.input = mock_vim_ui_input_spy

			current_parse_selected_latex_config["system of equations"] = {
				ast = {
					type = "solve_system_equations_capture",
					equations = {
						{ type = "equation", id = "eq1_ast" },
						{ type = "equation", id = "eq2_ast" },
					},
				},
				text = "eq1=0 \\\\ eq2=0",
			}
			current_solve_equation_config = { result = "solution_for_system", err = nil }
			vim_test_env.set_visual_selection(1, 1, 2, 1)
		end)

		after_each(function()
			vim.ui.input = original_vim_ui_input
		end)

		it("should process selection, prompt for vars, evaluate system, and insert result", function()
			commands_module.tungsten_solve_system_command({})
			assert.spy(mock_cmd_utils_parse_selected_latex_spy).was.called_with("system of equations")
			assert.spy(mock_solver_solve_equation_async_spy).was.called(1)
			local args = mock_solver_solve_equation_async_spy.calls[1].vals
			assert.are.same({ "wolfram(eq1_ast)", "wolfram(eq2_ast)" }, args[1])
			assert.is_true(args[3])
			assert.spy(mock_insert_result_insert_result_spy).was.called_with(
				"solution_for_system",
				" \\rightarrow ",
				match.is_number(),
				match.is_number(),
				"eq1=0 \\\\ eq2=0",
				match.is_string()
			)
		end)

		it("should log error if parsing fails (cmd_utils returns nil)", function()
			current_parse_selected_latex_config["system of equations"] = { ast = nil, text = "" }
			commands_module.tungsten_solve_system_command({})
			assert.spy(mock_solver_solve_equation_async_spy).was_not.called()
		end)
	end)

	describe(":TungstenToggleNumericMode", function()
		it("toggles config.numeric_mode", function()
			local cfg = require("tungsten.config")
			cfg.numeric_mode = false
			commands_module.tungsten_toggle_numeric_mode_command({})
			assert.is_true(cfg.numeric_mode)
			commands_module.tungsten_toggle_numeric_mode_command({})
			assert.is_false(cfg.numeric_mode)
		end)
	end)

	describe(":TungstenToggleDebugMode", function()
		it("toggles config.debug and adjusts logger level", function()
			local cfg = require("tungsten.config")
			cfg.debug = false
			cfg.log_level = "INFO"
			commands_module.tungsten_toggle_debug_mode_command({})
			assert.is_true(cfg.debug)
			assert.spy(mock_logger_module.set_level).was.called_with("DEBUG")
			commands_module.tungsten_toggle_debug_mode_command({})
			assert.is_false(cfg.debug)
			assert.spy(mock_logger_module.set_level).was.called_with("INFO")
			assert.spy(mock_logger_module.set_level).was.called(2)
		end)
	end)

	describe(":TungstenStatus", function()
		it("calls engine.get_active_jobs_summary and logs", function()
			mock_evaluator_module.get_active_jobs_summary = function()
				return "status"
			end
			local summary_spy = spy.on(mock_evaluator_module, "get_active_jobs_summary")
			commands_module.tungsten_status_command({})
			assert.spy(summary_spy).was.called()
			assert.spy(mock_logger_notify_spy).was.called_with("status", mock_logger_module.levels.INFO, match.is_table())
		end)
	end)
end)
