-- tests/unit/domains/plotting/commands_spec.lua
-- Unit tests for the user-facing plotting commands.

local spy = require("luassert.spy")
local mock_utils = require("tests.helpers.mock_utils")
local vim_test_env = require("tests.helpers.vim_test_env")

describe("Tungsten Plotting Commands", function()
	local plot_commands

	local mock_plot_workflow
	local mock_job_manager
	local mock_health_checker
	local mock_selection
	local mock_error_handler

	local run_simple_spy
	local run_advanced_spy
	local cancel_spy
	local cancel_all_spy
	local reset_deps_spy
	local check_deps_spy
	local notify_error_spy
	local get_selection_spy
	local notify_spy

	local current_selection

	local modules_to_reset = {
		"tungsten.domains.plotting.commands",
		"tungsten.domains.plotting.workflow",
		"tungsten.domains.plotting.job_manager",
		"tungsten.domains.plotting.health",
		"tungsten.util.selection",
		"tungsten.util.error_handler",
	}

	before_each(function()
		mock_utils.reset_modules(modules_to_reset)
		vim_test_env.setup_buffer({ "sin(x)" })

		mock_plot_workflow = mock_utils.create_empty_mock_module("tungsten.plot.workflow")
		run_simple_spy = spy.on(mock_plot_workflow, "run_simple")
		run_advanced_spy = spy.on(mock_plot_workflow, "run_advanced")

		mock_job_manager = mock_utils.create_empty_mock_module("tungsten.domains.plotting.job_manager")
		cancel_spy = spy.on(mock_job_manager, "cancel")
		cancel_all_spy = spy.on(mock_job_manager, "cancel_all")
		reset_deps_spy = spy.on(mock_job_manager, "reset_deps_check")

		mock_health_checker = mock_utils.create_empty_mock_module("tungsten.domains.plotting.health")
		check_deps_spy = spy.on(mock_health_checker, "check_dependencies")
		check_deps_spy = check_deps_spy:call_fake(function()
			return {
				wolframscript = { ok = true, version = "13.1.0" },
				python = { ok = true, version = "3.10.0" },
				numpy = { ok = true, version = "1.23.0" },
				sympy = { ok = true, version = "1.12" },
				matplotlib = { ok = true, version = "3.6.0" },
			}
		end)

		mock_error_handler = mock_utils.create_empty_mock_module("tungsten.util.error_handler")
		notify_error_spy = spy.on(mock_error_handler, "notify_error")

		current_selection = "sin(x)"
		mock_selection = mock_utils.create_empty_mock_module("tungsten.util.selection")
		get_selection_spy = spy.on(mock_selection, "get_visual_selection")
		get_selection_spy = get_selection_spy:call_fake(function()
			return current_selection
		end)

		plot_commands = require("tungsten.domains.plotting.commands")
		notify_spy = spy.on(vim, "notify")
	end)

	after_each(function()
		vim_test_env.cleanup()
		run_simple_spy:clear()
		run_advanced_spy:clear()
		cancel_spy:clear()
		cancel_all_spy:clear()
		reset_deps_spy:clear()
		check_deps_spy:clear()
		notify_error_spy:clear()
		get_selection_spy:clear()
		notify_spy:clear()
	end)

	describe(":TungstenPlot (Simple)", function()
		it("should provide a :TungstenPlot command for simple plots", function()
			assert.is_function(plot_commands.simple_plot_command)
		end)

		it("should invoke the simple plot workflow with the current visual selection", function()
			plot_commands.simple_plot_command()
			assert.spy(get_selection_spy).was.called(1)
			assert.spy(run_simple_spy).was.called(1)
			assert.spy(run_simple_spy).was.called_with("sin(x)")
		end)

		it("should produce an error if :TungstenPlot is invoked with no selection", function()
			current_selection = ""
			plot_commands.simple_plot_command()
			assert.spy(get_selection_spy).was.called(1)
			assert.spy(run_simple_spy).was_not.called()
			assert.spy(notify_error_spy).was.called(1)
			assert.spy(notify_error_spy).was.called_with("TungstenPlot", "Simple plot requires a visual selection.")
		end)

		it("should gracefully handle a nil selection", function()
			current_selection = nil
			plot_commands.simple_plot_command()
			assert.spy(notify_error_spy).was.called(1)
			assert.spy(notify_error_spy).was.called_with("TungstenPlot", "Simple plot requires a visual selection.")
		end)

		it("should trim whitespace from the selection before processing", function()
			current_selection = "  \n cos(x) \t "
			plot_commands.simple_plot_command()
			assert.spy(run_simple_spy).was.called_with("cos(x)")
		end)
	end)

	describe(":TungstenPlotAdvanced", function()
		it("should provide a :TungstenPlotAdvanced command that opens a config buffer", function()
			assert.is_function(plot_commands.advanced_plot_command)
		end)

		it("should invoke the advanced plot workflow", function()
			plot_commands.advanced_plot_command()
			assert.spy(run_advanced_spy).was.called(1)
		end)
	end)

	describe("Plot Job Management Commands", function()
		it("should allow canceling the latest running plot job with :TungstenPlotCancel", function()
			assert.is_function(plot_commands.cancel_command)
			mock_job_manager.active_jobs = { [1] = true, [3] = true }
			plot_commands.cancel_command()
			assert.spy(cancel_spy).was.called(1)
			assert.spy(cancel_spy).was.called_with(3)
		end)

		it("should cancel all queued and running plot jobs when :TungstenPlotCancelAll is invoked", function()
			assert.is_function(plot_commands.cancel_all_command)
			plot_commands.cancel_all_command()
			assert.spy(cancel_all_spy).was.called(1)
		end)
	end)

	describe(":TungstenPlotCheck", function()
		it("should perform a dependency check and report structured status with hints", function()
			assert.is_function(plot_commands.check_dependencies_command)
			mock_health_checker.check_dependencies = function()
				return {
					wolframscript = { ok = false, message = "required 13.0+, found none" },
					python = { ok = true, version = "3.10.0" },
					numpy = { ok = true, version = "1.23.0" },
					sympy = { ok = true, version = "1.12" },
					matplotlib = { ok = false, message = "required 3.6+, found none" },
				}
			end
			check_deps_spy = spy.on(mock_health_checker, "check_dependencies")
			plot_commands.check_dependencies_command()
			assert.spy(check_deps_spy).was.called(1)
			assert.spy(reset_deps_spy).was.called(1)
			assert.spy(notify_spy).was.called(1)
			local msg = notify_spy.calls[1].vals[1]
			assert.truthy(msg:match("1%. Wolfram"))
			assert.truthy(msg:match("2%. Python"))
			assert.truthy(msg:match("install matplotlib ≥3.6 via pip"))
		end)
	end)
end)
