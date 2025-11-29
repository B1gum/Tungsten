-- tests/unit/domains/plotting/commands_spec.lua
-- Unit tests for the user-facing plotting commands.

local spy = require("luassert.spy")
local mock_utils = require("tests.helpers.mock_utils")
local vim_test_env = require("tests.helpers.vim_test_env")
local wait_for = require("tests.helpers.wait").wait_for

describe("Tungsten Plotting Commands", function()
	local plot_commands

	local mock_plot_workflow
	local mock_job_manager
	local mock_health_checker
	local mock_selection
	local mock_error_handler

	local run_simple_spy
	local run_advanced_spy
	local run_parametric_spy
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
		"tungsten.ui.status_window",
	}

	before_each(function()
		mock_utils.reset_modules(modules_to_reset)
		vim_test_env.setup_buffer({ "sin(x)" })

		mock_plot_workflow = mock_utils.create_empty_mock_module("tungsten.domains.plotting.workflow")
		run_simple_spy = spy.on(mock_plot_workflow, "run_simple")
		run_advanced_spy = spy.on(mock_plot_workflow, "run_advanced")
		run_parametric_spy = spy.on(mock_plot_workflow, "run_parametric")

		mock_job_manager = mock_utils.create_empty_mock_module("tungsten.domains.plotting.job_manager")
		cancel_spy = spy.on(mock_job_manager, "cancel")
		cancel_spy = cancel_spy:call_fake(function()
			return true
		end)
		cancel_all_spy = spy.on(mock_job_manager, "cancel_all")
		reset_deps_spy = spy.on(mock_job_manager, "reset_deps_check")

		mock_health_checker = mock_utils.create_empty_mock_module("tungsten.domains.plotting.health")
		function mock_health_checker.check_dependencies(cb)
			if cb then
				cb({
					wolframscript = { ok = true, version = "13.1.0" },
					python = { ok = true, version = "3.10.0" },
					numpy = { ok = true, version = "1.23.0" },
					sympy = { ok = true, version = "1.12" },
					matplotlib = { ok = true, version = "3.6.0" },
				})
			end
		end
		check_deps_spy = spy.on(mock_health_checker, "check_dependencies")

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
		run_parametric_spy:clear()
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

	describe(":TungstenPlotParametric", function()
		it("should provide a :TungstenPlotParametric command that opens a config buffer", function()
			assert.is_function(plot_commands.parametric_plot_command)
		end)

		it("should invoke the parametric plot workflow", function()
			plot_commands.parametric_plot_command()
			assert.spy(run_parametric_spy).was.called(1)
		end)
	end)

	describe(":TungstenPlotParametric", function()
		it("should provide a :TungstenPlotParametric command that opens a config buffer", function()
			assert.is_function(plot_commands.parametric_plot_command)
		end)

		it("should invoke the parametric plot workflow", function()
			plot_commands.parametric_plot_command()
			assert.spy(run_parametric_spy).was.called(1)
		end)
	end)

	describe("Plot Job Management Commands", function()
		it("should allow canceling the latest running plot job with :TungstenPlotCancel", function()
			assert.is_function(plot_commands.cancel_command)
			mock_job_manager.active_jobs = { [1] = true, [3] = true }
			plot_commands.cancel_command()
			assert.spy(cancel_spy).was.called(1)
			assert.spy(cancel_spy).was.called_with(3)
			assert
				.spy(notify_spy).was
				.called_with("Cancelled plot job 3", vim.log.levels.INFO, { title = "TungstenPlotCancel" })
		end)

		it("should cancel all queued and running plot jobs when :TungstenPlotCancelAll is invoked", function()
			assert.is_function(plot_commands.cancel_all_command)
			plot_commands.cancel_all_command()
			assert.spy(cancel_all_spy).was.called(1)
		end)

		it("cancels a queued plot job before it starts", function()
			notify_spy:clear()
			vim_test_env.cleanup()
			vim_test_env.setup_buffer({ "queued" })

			mock_utils.reset_modules(modules_to_reset)

			local original_executable = vim.fn.executable
			vim.fn.executable = function(bin)
				if bin == "wolframscript" then
					return 1
				end
				return original_executable(bin)
			end

			local original_new_timer = vim.loop.new_timer
			vim.loop.new_timer = function()
				return {
					start = function() end,
					stop = function() end,
					close = function() end,
				}
			end

			package.loaded["tungsten.domains.plotting.workflow"] = {
				run_simple = function() end,
				run_advanced = function() end,
			}
			package.loaded["tungsten.util.selection"] = {
				get_visual_selection = function()
					return "x"
				end,
			}
			package.loaded["tungsten.util.error_handler"] = {
				notify_error = function() end,
				E_BACKEND_UNAVAILABLE = "E_BACKEND_UNAVAILABLE",
				E_UNSUPPORTED_FORM = "E_UNSUPPORTED_FORM",
				E_TIMEOUT = "E_TIMEOUT",
				E_BACKEND_CRASH = "E_BACKEND_CRASH",
				E_CANCELLED = "E_CANCELLED",
				E_NO_CONTOUR = "E_NO_CONTOUR",
				E_NO_ISOSURFACE = "E_NO_ISOSURFACE",
			}
			package.loaded["tungsten.ui.status_window"] = { open_queue = function() end }
			package.loaded["tungsten.util.logger"] = { debug = function() end, error = function() end }
			package.loaded["tungsten.util.plotting_io"] = {
				find_math_block_end = function()
					return 0
				end,
			}

			local mock_health = {}
			function mock_health.check_dependencies(cb)
				if cb then
					cb({
						wolframscript = { ok = true },
						python = { ok = true },
						matplotlib = { ok = true },
						sympy = { ok = true },
					})
				end
			end
			package.loaded["tungsten.domains.plotting.health"] = mock_health

			local run_calls = {}
			local mock_async = {}
			function mock_async.run_job(cmd, opts)
				table.insert(run_calls, { cmd = cmd, opts = opts })
				return {
					cancel = function()
						opts.on_exit(-1, "", "")
					end,
				}
			end
			package.loaded["tungsten.util.async"] = mock_async

			package.loaded["tungsten.config"] = { max_jobs = 1, plotting = {} }

			local job_manager = require("tungsten.domains.plotting.job_manager")
			plot_commands = require("tungsten.domains.plotting.commands")

			job_manager.submit({ expression = "first", bufnr = 0 })
			local second = job_manager.submit({ expression = "second", bufnr = 0 })
			job_manager.submit({ expression = "third", bufnr = 0 })

			assert.are.equal(1, #run_calls)
			assert.are.equal("first", run_calls[1].cmd.expression)

			plot_commands.cancel_command({ args = tostring(second) })

			assert
				.spy(notify_spy).was
				.called_with(string.format("Cancelled plot job %d", second), vim.log.levels.INFO, { title = "TungstenPlotCancel" })

			run_calls[1].opts.on_exit(0, "ok", "")

			assert.are.equal(2, #run_calls)
			assert.are.equal("third", run_calls[2].cmd.expression)
			for _, call in ipairs(run_calls) do
				assert.not_equal("second", call.cmd.expression)
			end

			vim.loop.new_timer = original_new_timer
			vim.fn.executable = original_executable
		end)
	end)

	describe(":TungstenPlotQueue", function()
		it("renders queue details for active and pending jobs", function()
			assert.is_function(plot_commands.queue_command)

			local api = vim.api
			local orig_create_buf = api.nvim_create_buf
			local orig_set_lines = api.nvim_buf_set_lines
			local orig_open_win = api.nvim_open_win
			local orig_set_option = api.nvim_buf_set_option

			local function restore_api()
				api.nvim_create_buf = orig_create_buf
				api.nvim_buf_set_lines = orig_set_lines
				api.nvim_open_win = orig_open_win
				api.nvim_buf_set_option = orig_set_option
			end

			local captured_lines
			local fake_start = os.time({ year = 2024, month = 1, day = 2, hour = 3, min = 4, sec = 5 })

			local function run_test()
				api.nvim_create_buf = function()
					return 101
				end
				api.nvim_buf_set_option = function() end
				api.nvim_open_win = function()
					return 202
				end
				api.nvim_buf_set_lines = function(_, _, _, _, lines)
					captured_lines = lines
				end

				mock_job_manager.get_queue_snapshot = function()
					return {
						active = {
							{
								id = 7,
								backend = "python",
								dim = 3,
								form = "explicit",
								expression = "sin(x)",
								ranges = {
									xrange = { 0, 1 },
									yrange = { -1, 1 },
								},
								started_at = fake_start,
								elapsed = 1.2,
								out_path = "/tmp/out.png",
							},
						},
						pending = {
							{
								id = 11,
								backend = "wolfram",
								dim = 2,
								form = "implicit",
								expression = "x^2 + y^2 = 1",
								ranges = {
									xrange = { -2, 2 },
								},
								out_path = "/tmp/pending.pdf",
							},
						},
					}
				end

				local snapshot_spy = spy.on(mock_job_manager, "get_queue_snapshot")

				plot_commands.queue_command()

				assert.spy(snapshot_spy).was.called(1)
				assert.is_truthy(captured_lines)
				local rendered = table.concat(captured_lines, "\n")
				assert.matches("python", rendered)
				assert.matches("3D explicit", rendered)
				assert.matches("sin%(x%)", rendered)
				assert.matches("x:%s*%[0, 1%]", rendered)
				assert.matches("; y:", rendered)
				assert.matches(os.date("%H:%M:%S", fake_start), rendered)
				assert.matches("1%.2s", rendered)
				assert.matches("/tmp/out%.png", rendered)
				assert.matches("wolfram", rendered)
				assert.matches("2D implicit", rendered)
				assert.matches("x%^2%s*%+%s*y%^2 = 1", rendered)
				assert.matches("/tmp/pending%.pdf", rendered)
			end

			local ok, err = pcall(run_test)
			restore_api()
			if not ok then
				error(err)
			end
		end)
	end)

	describe(":TungstenPlotCheck", function()
		it("should perform a dependency check and report structured status with hints", function()
			assert.is_function(plot_commands.check_dependencies_command)
			mock_health_checker.check_dependencies = function(cb)
				vim.schedule(function()
					cb({
						wolframscript = { ok = false, message = "required 1.10.0+, found none" },
						python = { ok = true, version = "3.10.0" },
						numpy = { ok = true, version = "1.23.0" },
						sympy = { ok = true, version = "1.12" },
						matplotlib = { ok = false, message = "required 3.6+, found none" },
					})
				end)
			end
			check_deps_spy = spy.on(mock_health_checker, "check_dependencies")
			plot_commands.check_dependencies_command()
			wait_for(function()
				return #notify_spy.calls > 0
			end, 200)
			assert.spy(check_deps_spy).was.called()
			assert.spy(reset_deps_spy).was.called()
			assert.spy(notify_spy).was.called()
			local last_call = notify_spy.calls[#notify_spy.calls]
			local msg = last_call.vals[1]
			assert.truthy(msg:match("1%. Wolfram"))
			assert.truthy(msg:match("2%. Python"))
			assert.truthy(msg:match("install matplotlib ≥3.6 via pip"))
		end)
	end)
end)
