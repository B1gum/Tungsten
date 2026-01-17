local spy = require("luassert.spy")
local mock_utils = require("tests.helpers.mock_utils")
local vim_test_env = require("tests.helpers.vim_test_env")

describe("Plotting workflow runner", function()
	local runner
	local mock_parser
	local mock_classification_merge
	local mock_options_builder
	local mock_error_handler
	local mock_plotting_io
	local mock_plotting_ui
	local mock_job_submit
	local mock_ast
	local mock_selection_utils

	local modules_to_reset = {
		"tungsten.domains.plotting.workflow.runner",
		"tungsten.core.parser",
		"tungsten.core.ast",
		"tungsten.domains.plotting.options_builder",
		"tungsten.domains.plotting.workflow.classification_merge",
		"tungsten.util.error_handler",
		"tungsten.domains.plotting.io",
		"tungsten.ui.plotting",
		"tungsten.util.plotting.job_submit",
		"tungsten.domains.plotting.workflow.selection",
	}

	before_each(function()
		mock_utils.reset_modules(modules_to_reset)
		vim_test_env.setup_buffer({ "sin(x)" })
		vim_test_env.set_visual_selection(1, 1, 1, 7)

		mock_parser = {
			parse = spy.new(function()
				return {
					series = {
						{ type = "variable", name = "a" },
						{ type = "variable", name = "b" },
					},
				}
			end),
		}
		package.loaded["tungsten.core.parser"] = mock_parser

		mock_classification_merge = {
			merge = spy.new(function(series)
				return { form = "explicit", series = series }
			end),
		}
		package.loaded["tungsten.domains.plotting.workflow.classification_merge"] = mock_classification_merge

		mock_options_builder = {
			build = spy.new(function(classification_data)
				return {
					form = classification_data.form,
					series = vim.deepcopy(classification_data.series),
				}
			end),
		}
		package.loaded["tungsten.domains.plotting.options_builder"] = mock_options_builder

		mock_error_handler = {
			notify_error = spy.new(function() end),
			E_BAD_OPTS = "E_BAD_OPTS",
			E_BACKEND_CRASH = "E_BACKEND_CRASH",
			E_UNSUPPORTED_FORM = "E_UNSUPPORTED_FORM",
		}
		package.loaded["tungsten.util.error_handler"] = mock_error_handler

		mock_plotting_io = {
			resolve_paths = spy.new(function()
				return "/tmp/main.tex", "/tmp/plots", false, nil
			end),
			assign_output_path = spy.new(function(opts)
				opts.out_path = "/tmp/plots/plot.pdf"
				return opts.out_path, nil
			end),
		}
		package.loaded["tungsten.domains.plotting.io"] = mock_plotting_io

		mock_plotting_ui = {
			handle_undefined_symbols = spy.new(function(_, cb)
				if cb then
					cb({})
				end
			end),
			open_advanced_config = spy.new(function() end),
		}
		package.loaded["tungsten.ui.plotting"] = mock_plotting_ui

		mock_job_submit = {
			submit = spy.new(function() end),
		}
		package.loaded["tungsten.util.plotting.job_submit"] = mock_job_submit

		mock_ast = {
			create_sequence_node = spy.new(function(nodes)
				return { type = "Sequence", nodes = nodes }
			end),
			create_number_node = spy.new(function(value)
				return { type = "number", value = value }
			end),
		}
		package.loaded["tungsten.core.ast"] = mock_ast

		mock_selection_utils = {
			get_selection_range = spy.new(function()
				return 1, 2, 3, 4, 5
			end),
			get_trimmed_visual_selection = spy.new(function()
				return "sin(x)"
			end),
		}
		package.loaded["tungsten.domains.plotting.workflow.selection"] = mock_selection_utils

		runner = require("tungsten.domains.plotting.workflow.runner")
	end)

	after_each(function()
		mock_utils.reset_modules(modules_to_reset)
		vim_test_env.cleanup()
	end)

	it("notifies on empty simple input", function()
		runner.run_simple({})

		assert
			.spy(mock_error_handler.notify_error).was
			.called_with("TungstenPlot", mock_error_handler.E_BAD_OPTS, nil, nil, "Simple plot requires an expression")
	end)

	it("handles parse errors in advanced selections", function()
		mock_selection_utils.get_trimmed_visual_selection = spy.new(function()
			return "bad"
		end)
		mock_parser.parse = spy.new(function()
			error("parse exploded")
		end)

		runner.run_advanced()

		assert.spy(mock_error_handler.notify_error).was.called()
		assert.spy(mock_plotting_ui.open_advanced_config).was_not_called()
	end)

	it("surfaces classification merge failures", function()
		mock_classification_merge.merge = spy.new(function()
			return nil, "bad classification"
		end)

		runner.run_parametric()

		assert.spy(mock_error_handler.notify_error).was.called()
		assert.spy(mock_plotting_ui.open_advanced_config).was_not_called()
	end)

	it("substitutes definitions and rebuilds options", function()
		local merge_calls = 0
		mock_classification_merge.merge = spy.new(function(series)
			merge_calls = merge_calls + 1
			if merge_calls == 2 then
				assert.are.same({
					{ type = "number", value = 2 },
					{ type = "number", value = 3 },
				}, series)
			end
			return { form = "explicit", series = series }
		end)

		mock_plotting_ui.handle_undefined_symbols = spy.new(function(opts, cb)
			assert.are.equal("Sequence", opts.ast.type)
			cb({
				definitions = {
					a = { value = 2 },
					b = { value = 3 },
				},
			})
		end)

		runner.run_simple("sin(x)")

		assert.are.equal(2, merge_calls)
		assert.spy(mock_options_builder.build).was.called(2)
		assert.spy(mock_job_submit.submit).was.called(1)
		local submitted_opts = mock_job_submit.submit.calls[1].vals[1]
		assert.are.same({
			a = { value = 2 },
			b = { value = 3 },
		}, submitted_opts.definitions)
	end)

	it("keeps the original options when reclassification fails", function()
		local merge_calls = 0
		mock_classification_merge.merge = spy.new(function(series)
			merge_calls = merge_calls + 1
			if merge_calls == 2 then
				return nil, { message = "reclass failed" }
			end
			return { form = "explicit", series = series }
		end)

		mock_plotting_ui.handle_undefined_symbols = spy.new(function(_, cb)
			cb({ definitions = { a = { value = 2 } } })
		end)

		runner.run_simple("sin(x)")

		assert.spy(mock_error_handler.notify_error).was.called()
		assert.spy(mock_job_submit.submit).was.called(1)
	end)

	it("reports path resolution failures and aborts submission", function()
		mock_plotting_io.resolve_paths = spy.new(function()
			return nil, nil, nil, "missing tex root"
		end)

		runner.run_simple("sin(x)")

		assert.spy(mock_error_handler.notify_error).was.called()
		assert.spy(mock_job_submit.submit).was_not_called()
	end)

	it("rejects parametric forms in advanced mode", function()
		mock_classification_merge.merge = spy.new(function()
			return { form = "parametric", series = { { type = "expr" } } }
		end)

		runner.run_advanced()

		assert.spy(mock_error_handler.notify_error).was.called_with(
			"TungstenPlot",
			mock_error_handler.E_UNSUPPORTED_FORM,
			nil,
			nil,
			"Use :TungstenPlotParametric for parametric plots."
		)
	end)

	it("submits advanced plots through the UI callback", function()
		mock_plotting_ui.open_advanced_config = spy.new(function(opts)
			opts.on_submit({ bufnr = 0, expression = "custom" })
		end)

		runner.run_advanced()

		assert.spy(mock_plotting_io.resolve_paths).was.called()
		assert.spy(mock_plotting_io.assign_output_path).was.called()
		assert.spy(mock_job_submit.submit).was.called(1)
		local submitted_opts = mock_job_submit.submit.calls[1].vals[1]
		assert.are.equal(vim.api.nvim_get_current_buf(), submitted_opts.bufnr)
		assert.are.equal("custom", submitted_opts.expression)
	end)

	it("submits parametric plots through the UI callback", function()
		mock_plotting_ui.open_advanced_config = spy.new(function(opts)
			opts.on_submit({ bufnr = 1 })
		end)

		runner.run_parametric()

		assert.spy(mock_parser.parse).was.called_with("sin(x)", { mode = "advanced", form = "parametric" })
		assert.spy(mock_job_submit.submit).was.called(1)
	end)
end)
