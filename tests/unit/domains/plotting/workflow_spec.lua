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
			return "/tmp/project/tungsten_plots"
		end)
		mock_io.get_final_path = spy.new(function()
			return "/tmp/project/tungsten_plots/plot.pdf", false
		end)
		package.loaded["tungsten.domains.plotting.io"] = mock_io

		mock_job_manager = {}
		mock_job_manager.submit = spy.new(function() end)
		package.loaded["tungsten.domains.plotting.job_manager"] = mock_job_manager

		mock_error_handler = {}
		mock_error_handler.notify_error = spy.new(function() end)
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

		mock_ui = { start_plot_workflow = spy.new(function() end) }
		package.loaded["tungsten.ui.plotting"] = mock_ui

		workflow = require("tungsten.domains.plotting.workflow")
	end)

	after_each(function()
		mock_utils.reset_modules(modules_to_reset)
		vim_test_env.cleanup()
		if original_mode then
			vim.fn.mode = original_mode
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

	it("delegates advanced mode to the plotting UI", function()
		workflow.run_advanced()
		assert.spy(mock_ui.start_plot_workflow).was.called(1)
	end)
end)
