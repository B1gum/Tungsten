local spy = require("luassert.spy")
local mock_utils = require("tests.helpers.mock_utils")
local vim_test_env = require("tests.helpers.vim_test_env")

describe("Plotting workflow", function()
	local workflow
	local mock_parser
	local mock_classification
	local mock_options_builder
	local mock_io
	local mock_job_manager
	local mock_error_handler
	local mock_async
	local mock_backend
	local backend_calls
	local mock_ui
	local original_prompt

	local function unique_tex_path()
		local stamp = vim.loop.hrtime()
		return string.format("/tmp/project/main_%d.tex", stamp % 1000000)
	end

	local modules_to_reset = {
		"tungsten.domains.plotting.workflow",
		"tungsten.core.parser",
		"tungsten.domains.plotting.classification",
		"tungsten.domains.plotting.options_builder",
		"tungsten.domains.plotting.io",
		"tungsten.domains.plotting.job_manager",
		"tungsten.util.error_handler",
		"tungsten.util.async",
		"tungsten.backends.wolfram",
		"tungsten.core.ast",
		"tungsten.ui.plotting",
		"tungsten.util.selection",
	}

	local original_mode

	before_each(function()
		mock_utils.reset_modules(modules_to_reset)

		vim_test_env.setup_buffer({ "sin(x)" })
		vim_test_env.set_visual_selection(1, 1, 1, 7)
		original_mode = vim.fn.mode
		vim.fn.mode = function()
			return "v"
		end
		backend_calls = 0

		mock_parser = {}
		mock_parser.parse = spy.new(function()
			return { series = { { type = "expr", value = "ast" } } }
		end)
		package.loaded["tungsten.core.parser"] = mock_parser

		mock_classification = {}
		mock_classification.analyze = spy.new(function()
			return {
				dim = 2,
				form = "explicit",
				series = {
					{
						kind = "function",
						ast = { type = "expr", body = "ast" },
						independent_vars = { "x" },
						dependent_vars = { "y" },
					},
				},
			}
		end)
		package.loaded["tungsten.domains.plotting.classification"] = mock_classification

		mock_options_builder = {}
		mock_options_builder.build = spy.new(function(classification_data)
			return {
				dim = classification_data.dim,
				form = classification_data.form,
				backend = "wolfram",
				format = "pdf",
				timeout_ms = 30000,
				series = vim.deepcopy(classification_data.series),
			}
		end)
		package.loaded["tungsten.domains.plotting.options_builder"] = mock_options_builder

		mock_io = {}
		mock_io.find_tex_root = spy.new(function()
			return "/tmp/project/main.tex"
		end)
		mock_io.get_output_directory = spy.new(function()
			return "/tmp/project/tungsten_plots", nil, false
		end)
		mock_io.get_final_path = spy.new(function()
			return "/tmp/project/tungsten_plots/plot.pdf", false
		end)
		package.loaded["tungsten.domains.plotting.io"] = mock_io

		mock_job_manager = {}
		mock_job_manager.submit = spy.new(function() end)
		mock_job_manager.apply_output = spy.new(function() end)
		package.loaded["tungsten.domains.plotting.job_manager"] = mock_job_manager

		mock_error_handler = {
			notify_error = spy.new(function() end),
			E_UNSUPPORTED_FORM = "E_UNSUPPORTED_FORM",
			E_INVALID_CLASSIFICATION = "E_INVALID_CLASSIFICATION",
			E_NO_PLOTTABLE_SERIES = "E_NO_PLOTTABLE_SERIES",
			E_BAD_OPTS = "E_BAD_OPTS",
			E_BACKEND_CRASH = "E_BACKEND_CRASH",
		}
		package.loaded["tungsten.util.error_handler"] = mock_error_handler

		mock_async = {}
		mock_async.run_job = function()
			return {}
		end
		package.loaded["tungsten.util.async"] = mock_async

		mock_backend = {}
		function mock_backend.plot_async(opts, cb)
			backend_calls = backend_calls + 1
			local async_mod = require("tungsten.util.async")
			async_mod.run_job({ "wolfram", "-code", "plot" }, { timeout = opts.timeout_ms })
			if cb then
				cb(nil, opts.out_path)
			end
		end
		package.loaded["tungsten.backends.wolfram"] = mock_backend

		package.loaded["tungsten.core.ast"] = {
			create_sequence_node = function(nodes)
				return { type = "Sequence", nodes = nodes }
			end,
		}

		mock_ui = {
			start_plot_workflow = spy.new(function() end),
			open_advanced_config = spy.new(function() end),
			handle_undefined_symbols = spy.new(function(opts, cb)
				if type(opts) ~= "table" then
					opts = {}
				end
				opts.definitions = opts.definitions or {}
				if cb then
					cb(opts)
				end
			end),
		}
		package.loaded["tungsten.ui.plotting"] = mock_ui

		package.loaded["tungsten.util.selection"] = {
			get_visual_selection = function()
				return "sin(x)"
			end,
		}

		workflow = require("tungsten.domains.plotting.workflow")
		original_prompt = workflow._show_regenerate_prompt
	end)

	after_each(function()
		mock_utils.reset_modules(modules_to_reset)
		vim_test_env.cleanup()
		if original_mode then
			vim.fn.mode = original_mode
		end
		if workflow and original_prompt then
			workflow._show_regenerate_prompt = original_prompt
		end
	end)

	it("assembles a plot job from the visual selection", function()
		vim.api.nvim_buf_set_name(0, "/tmp/project/main.tex")

		workflow.run_simple("sin(x)")

		assert.spy(mock_error_handler.notify_error).was_not_called()

		assert.spy(mock_parser.parse).was.called_with("sin(x)", { simple_mode = true })
		assert.spy(mock_classification.analyze).was.called(1)
		assert.spy(mock_options_builder.build).was.called(1)
		assert.spy(mock_io.find_tex_root).was.called(1)
		assert.are.equal(1, backend_calls)
		assert.spy(mock_job_manager.submit).was.called(1)

		local submitted = mock_job_manager.submit.calls[1].vals[1]
		assert.are.equal("wolfram", submitted.backend)
		assert.are.equal("/tmp/project/tungsten_plots/plot.pdf", submitted.out_path)
		assert.are.equal("sin(x)", submitted.expression)
		assert.are.equal(vim.api.nvim_get_current_buf(), submitted.bufnr)
		assert.are.equal(0, submitted.start_line)
		assert.are.equal(0, submitted.start_col)
		assert.are.equal(0, submitted.end_line)
		assert.are.equal(0, submitted.end_col)
		assert.are.same({ "wolfram", "-code", "plot" }, { submitted[1], submitted[2], submitted[3] })
	end)

	it("trims leading and trailing whitespace before parsing", function()
		vim.api.nvim_buf_set_name(0, "/tmp/project/main_trimmed.tex")
		workflow.run_simple("  \n  sin(x)  \t\n")
		assert.spy(mock_parser.parse).was.called_with("sin(x)", { simple_mode = true })
	end)

	it("reuses existing simple plots without starting the backend", function()
		vim.api.nvim_buf_set_name(0, unique_tex_path())

		mock_io.get_final_path = spy.new(function()
			return "/tmp/project/tungsten_plots/plot.pdf", true
		end)

		workflow.run_simple("sin(x)")

		assert.are.equal(0, backend_calls)
		assert.spy(mock_job_manager.submit).was_not_called()
		assert.spy(mock_job_manager.apply_output).was.called(1)
		assert.spy(mock_io.get_final_path).was.called(1)
	end)

	it("prompts for definitions when simple plots have undefined symbols", function()
		vim.api.nvim_buf_set_name(0, unique_tex_path())

		local captured_opts
		local resolver
		mock_ui.handle_undefined_symbols = spy.new(function(opts, cb)
			captured_opts = opts
			resolver = cb
		end)

		workflow.run_simple("sin(x)")

		assert.spy(mock_ui.handle_undefined_symbols).was.called(1)
		assert.are.equal("sin(x)", captured_opts.expression)
		assert.is_not_nil(captured_opts.ast)
		assert.spy(mock_job_manager.submit).was_not_called()

		local definitions = { c = { latex = "2" } }
		assert.is_function(resolver)
		resolver({ definitions = definitions })

		assert.spy(mock_job_manager.submit).was.called(1)
		local submitted = mock_job_manager.submit.calls[1].vals[1]
		assert.are.same(definitions, submitted.definitions)

		local final_plot_data = mock_io.get_final_path.calls[1].vals[3]
		assert.are.same(definitions, final_plot_data.var_defs)
	end)

	it("surfaces E_UNSUPPORTED_FORM when Python backend lacks implicit 3D support", function()
		vim.api.nvim_buf_set_name(0, unique_tex_path())

		mock_classification.analyze = spy.new(function()
			return {
				dim = 3,
				form = "implicit",
				series = {
					{
						kind = "function",
						ast = { type = "expr", body = "ast" },
						independent_vars = { "x", "y", "z" },
						dependent_vars = { "w" },
					},
				},
			}
		end)

		mock_options_builder.build = spy.new(function(classification_data)
			return {
				dim = classification_data.dim,
				form = classification_data.form,
				backend = "python",
				format = "png",
				timeout_ms = 30000,
				series = vim.deepcopy(classification_data.series),
			}
		end)

		workflow.run_simple("sin(x)")

		assert.spy(mock_job_manager.submit).was_not_called()
		assert.spy(mock_error_handler.notify_error).was.called_with(
			"TungstenPlot",
			mock_error_handler.E_UNSUPPORTED_FORM,
			nil,
			nil,
			"Implicit 3D plots are not supported by the Python backend"
		)
	end)

	it("reports parse errors", function()
		mock_parser.parse = spy.new(function()
			return nil, "Parse error", 2, "x"
		end)
		package.loaded["tungsten.core.parser"] = mock_parser
		mock_utils.reset_modules({ "tungsten.domains.plotting.workflow" })
		workflow = require("tungsten.domains.plotting.workflow")

		workflow.run_simple("bad")

		assert.spy(mock_error_handler.notify_error).was.called()
		assert.spy(mock_job_manager.submit).was_not_called()
	end)

	it("tags missing simple input as E_BAD_OPTS and surfaces the human message", function()
		workflow.run_simple("")

		assert
			.spy(mock_error_handler.notify_error).was
			.called_with("TungstenPlot", mock_error_handler.E_BAD_OPTS, nil, nil, "Simple plot requires an expression")
	end)

	it("maps backend command failures to E_BACKEND_CRASH without clobbering the message", function()
		vim.api.nvim_buf_set_name(0, unique_tex_path())

		mock_backend.plot_async = function(_, cb)
			backend_calls = backend_calls + 1
			if cb then
				cb("Backend exploded")
			end
		end

		workflow.run_simple("sin(x)")

		assert
			.spy(mock_error_handler.notify_error).was
			.called_with("TungstenPlot", mock_error_handler.E_BACKEND_CRASH, nil, nil, "Backend exploded")
	end)

	it("surfaces E_NO_PLOTTABLE_SERIES when classification omits dimension or series", function()
		vim.api.nvim_buf_set_name(0, unique_tex_path())

		mock_classification.analyze = spy.new(function()
			return {
				form = nil,
				series = {},
			}
		end)

		workflow.run_simple("sin(x)")

		assert.spy(mock_job_manager.submit).was_not_called()
		assert.spy(mock_error_handler.notify_error)
	end)

	it("computes advanced plotting context from the visual selection", function()
		workflow.run_advanced()
		assert.spy(mock_ui.open_advanced_config).was.called(1)
		assert.spy(mock_ui.start_plot_workflow).was_not_called()
		local advanced_opts = mock_ui.open_advanced_config.calls[1].vals[1]
		assert.are.equal("sin(x)", advanced_opts.expression)
		assert.is_table(advanced_opts.classification)
		assert.are.equal(2, advanced_opts.classification.dim)
		assert.are.equal("explicit", advanced_opts.classification.form)
		assert.is_table(advanced_opts.series)
		assert.are.equal(1, #advanced_opts.series)
		assert.is_table(advanced_opts.parsed_series)
		assert.are.equal(1, #advanced_opts.parsed_series)
		assert.is_not_nil(advanced_opts.ast)
		assert.are.equal(vim.api.nvim_get_current_buf(), advanced_opts.bufnr)
		assert.is_function(advanced_opts.on_submit)
	end)

	it("drives advanced submissions through the UI callback", function()
		vim.api.nvim_buf_set_name(0, unique_tex_path())

		mock_ui.open_advanced_config = spy.new(function(opts)
			assert.is_function(opts.on_submit)
			local final_opts = vim.deepcopy(opts)
			final_opts.backend = "wolfram"
			final_opts.format = "pdf"
			final_opts.timeout_ms = 30000
			opts.on_submit(final_opts)
		end)

		workflow.run_advanced()

		assert.spy(mock_job_manager.submit).was.called(1)
		local submitted = mock_job_manager.submit.calls[1].vals[1]
		assert.are.equal("wolfram", submitted.backend)
	end)

	it("submits advanced plots immediately when not reusing an artifact", function()
		vim.api.nvim_buf_set_name(0, unique_tex_path())

		workflow.run_advanced()

		local advanced_opts = mock_ui.open_advanced_config.calls[1].vals[1]
		assert.is_function(advanced_opts.on_submit)

		workflow._show_regenerate_prompt = spy.new(function() end)

		local final_opts = vim.deepcopy(advanced_opts)
		final_opts.backend = "wolfram"
		final_opts.format = "pdf"
		final_opts.timeout_ms = 30000

		advanced_opts.on_submit(final_opts)

		assert.is_false(final_opts.reused_output)
		assert.spy(mock_job_manager.submit).was.called(1)
		assert.spy(workflow._show_regenerate_prompt).was_not_called()
	end)

	it("prompts before regenerating an existing advanced artifact", function()
		vim.api.nvim_buf_set_name(0, unique_tex_path())

		mock_io.get_final_path = spy.new(function()
			return "/tmp/project/tungsten_plots/plot.pdf", true
		end)
		package.loaded["tungsten.domains.plotting.io"] = mock_io
		mock_utils.reset_modules({ "tungsten.domains.plotting.workflow" })
		workflow = require("tungsten.domains.plotting.workflow")
		original_prompt = workflow._show_regenerate_prompt

		workflow.run_advanced()

		local advanced_opts = mock_ui.open_advanced_config.calls[1].vals[1]
		local final_opts = vim.deepcopy(advanced_opts)
		final_opts.backend = "wolfram"
		final_opts.format = "pdf"
		final_opts.timeout_ms = 30000

		local confirm_cb
		workflow._show_regenerate_prompt = function(on_confirm)
			confirm_cb = on_confirm
		end

		advanced_opts.on_submit(final_opts)

		assert.is_true(final_opts.reused_output)
		assert.spy(mock_job_manager.submit).was_not_called()
		assert.is_function(confirm_cb)
		assert.are.equal(0, backend_calls)
		assert.spy(mock_job_manager.apply_output).was_not_called()

		confirm_cb()

		assert.spy(mock_job_manager.submit).was.called(1)
		assert.are.equal(1, backend_calls)
	end)

	it("allows skipping regeneration when declining the prompt", function()
		vim.api.nvim_buf_set_name(0, unique_tex_path())

		mock_io.get_final_path = spy.new(function()
			return "/tmp/project/tungsten_plots/plot.pdf", true
		end)
		package.loaded["tungsten.domains.plotting.io"] = mock_io
		mock_utils.reset_modules({ "tungsten.domains.plotting.workflow" })
		workflow = require("tungsten.domains.plotting.workflow")
		original_prompt = workflow._show_regenerate_prompt

		workflow.run_advanced()

		local advanced_opts = mock_ui.open_advanced_config.calls[1].vals[1]
		local final_opts = vim.deepcopy(advanced_opts)
		final_opts.backend = "wolfram"
		final_opts.format = "pdf"
		final_opts.timeout_ms = 30000

		local confirm_cb, cancel_cb
		workflow._show_regenerate_prompt = function(on_confirm, on_cancel)
			confirm_cb = on_confirm
			cancel_cb = on_cancel
		end

		advanced_opts.on_submit(final_opts)

		assert.spy(mock_job_manager.submit).was_not_called()
		assert.is_function(cancel_cb)

		cancel_cb()

		assert.spy(mock_job_manager.submit).was_not_called()
		assert.spy(mock_job_manager.apply_output).was.called(1)
		assert.are.equal(0, backend_calls)
		assert.is_function(confirm_cb)
	end)
end)
