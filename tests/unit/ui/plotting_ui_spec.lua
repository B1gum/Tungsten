-- Unit tests for the Plotting UI and user experience workflows.

local spy = require("luassert.spy")
local stub = require("luassert.stub")
local match = require("luassert.match")
local mock_utils = require("tests.helpers.mock_utils")
local vim_test_env = require("tests.helpers.vim_test_env")

local mock_plotting_core
local mock_error_handler
local mock_state
local mock_config
local mock_async
local mock_io
local mock_options_builder

local plotting_ui

local function setup_test_environment()
	mock_utils.reset_modules({
		"tungsten.ui.plotting",
		"tungsten.core.plotting",
		"tungsten.util.error_handler",
		"tungsten.state",
		"tungsten.config",
		"tungsten.util.async",
		"tungsten.util.io",
		"tungsten.domains.plotting.options_builder",
	})

	mock_plotting_core = mock_utils.create_empty_mock_module("tungsten.core.plotting", {
		"initiate_plot",
		"get_undefined_symbols",
		"generate_hash",
	})
	mock_error_handler = mock_utils.create_empty_mock_module("tungsten.util.error_handler", { "notify_error" })
	mock_error_handler.E_VIEWER_FAILED = "E_VIEWER_FAILED"
	mock_state = { persistent_variables = {} }
	mock_config = {
		plotting = {
			snippet_width = "0.8\\linewidth",
			viewer_cmd_pdf = "open",
			viewer_cmd_png = "open",
		},
	}
	mock_async = mock_utils.create_empty_mock_module("tungsten.util.async", { "run_job" })
	mock_io = mock_utils.create_empty_mock_module("tungsten.util.io", { "find_math_block_end" })
	mock_options_builder = mock_utils.create_empty_mock_module("tungsten.domains.plotting.options_builder", { "build" })
	mock_options_builder.build = stub.new(mock_options_builder, "build", function(classification_arg, overrides)
		local result = { series = {} }
		if type(classification_arg) == "table" then
			if classification_arg.dim then
				result.dim = classification_arg.dim
			end
			if classification_arg.form then
				result.form = classification_arg.form
			end
			local src_series = classification_arg.series or {}
			for i = 1, #src_series do
				result.series[i] = {}
			end
		end
		if type(overrides) == "table" then
			for k, v in pairs(overrides) do
				result[k] = v
			end
		end
		return result
	end)

	package.loaded["tungsten.state"] = mock_state
	package.loaded["tungsten.config"] = mock_config

	plotting_ui = require("tungsten.ui.plotting")
end

describe("Plotting UI and UX", function()
	before_each(setup_test_environment)

	describe("Undefined Symbol Prompt", function()
		local original_vim_ui_input

		before_each(function()
			original_vim_ui_input = vim.ui.input
		end)

		after_each(function()
			vim.ui.input = original_vim_ui_input
		end)

		it("should prompt the user to define values for undefined variables", function()
			mock_plotting_core.get_undefined_symbols:returns({
				{ name = "a", type = "variable" },
				{ name = "b", type = "variable" },
			})
			vim.ui.input = stub.new(vim.ui, "input", function(opts, on_confirm)
				on_confirm(nil)
			end)

			plotting_ui.handle_undefined_symbols({}, function() end)

			assert.spy(vim.ui.input).was.called(1)
			local prompt_opts = vim.ui.input.calls[1].vals[1]
			assert.truthy(prompt_opts.prompt:find("Define symbols for plot:"))
			assert.truthy(prompt_opts.default:find("a = "))
			assert.truthy(prompt_opts.default:find("b = "))
		end)

		it("should first apply persistent variables before prompting", function()
			mock_state.persistent_variables = { a = "5" }
			mock_plotting_core.get_undefined_symbols:returns({ { name = "b", type = "variable" } })
			vim.ui.input = stub.new(vim.ui, "input", function(_, on_confirm)
				on_confirm(nil)
			end)

			plotting_ui.handle_undefined_symbols({}, function() end)

			assert.spy(vim.ui.input).was.called(1)
			local prompt_default = vim.ui.input.calls[1].vals[1].default
			assert.falsy(prompt_default:find("a ="))
			assert.truthy(prompt_default:find("b = "))
		end)

		it("should parse definitions from the user input", function()
			mock_plotting_core.get_undefined_symbols:returns({
				{ name = "a", type = "variable" },
				{ name = "f", type = "function" },
			})

			vim.ui.input = stub.new(vim.ui, "input", function(_, on_confirm)
				on_confirm("a = 10\nf(x) := x^2")
			end)

			local callback_spy = spy.new()

			plotting_ui.handle_undefined_symbols({}, callback_spy)

			assert.spy(callback_spy).was.called(1)
			local definitions = callback_spy.calls[1].vals[1]
			assert.is_table(definitions)
			assert.are.same("10", definitions.a.latex)
			assert.are.same("x^2", definitions["f(x)"].latex)
		end)

		it("should include one-time definitions in the options passed for hashing and plotting", function()
			local callback_spy = spy.new(function(plot_opts)
				mock_plotting_core.initiate_plot(plot_opts)
			end)
			mock_plotting_core.get_undefined_symbols:returns({ { name = "k", type = "variable" } })

			vim.ui.input = stub.new(vim.ui, "input", function(_, on_confirm)
				on_confirm("k = 9.8")
			end)

			plotting_ui.handle_undefined_symbols({ original_ast = "some_ast" }, callback_spy)

			assert.spy(mock_plotting_core.initiate_plot).was.called(1)
			local final_plot_opts = mock_plotting_core.initiate_plot.calls[1].vals[1]
			assert.are.same("9.8", final_plot_opts.definitions.k.latex)
		end)

		it("should notify error if a definition cannot be evaluated to a real number", function()
			local error_callback
			mock_plotting_core.initiate_plot = spy.new(function(opts)
				if opts.on_error then
					error_callback = opts.on_error
				end
			end)
			plotting_ui.start_plot_workflow({})

			error_callback("E_EVAL_FAILED", "Could not evaluate 'a' to a real number.")

			assert
				.spy(mock_error_handler.notify_error).was
				.called_with("Plot Error", "E_EVAL_FAILED", nil, nil, "Could not evaluate 'a' to a real number.")
		end)
	end)

	describe("Snippet Insertion", function()
		it("should insert the \\includegraphics snippet on a new line after the math block", function()
			local bufnr = vim_test_env.setup_buffer({ "Some text before", "$$ sin(x) $$", "Some text after" })
			mock_io.find_math_block_end:returns(2)
			local set_lines_spy = stub(vim.api, "nvim_buf_set_lines")

			plotting_ui.insert_snippet(bufnr, 2, "plots/myplot_123")

			assert
				.spy(set_lines_spy).was
				.called_with(bufnr, 3, 3, false, { "", "\\includegraphics[width=0.8\\linewidth]{plots/myplot_123}" })
			set_lines_spy:revert()
		end)

		it("should use a default width of 0.8\\linewidth", function()
			local bufnr = vim_test_env.setup_buffer({ "$$x$$" })
			mock_io.find_math_block_end:returns(1)
			local set_lines_spy = stub(vim.api, "nvim_buf_set_lines")

			plotting_ui.insert_snippet(bufnr, 1, "myplot")

			local inserted_lines = set_lines_spy.calls[1].vals[5]
			local inserted_text = inserted_lines[#inserted_lines]
			assert.truthy(inserted_text:find("width=0.8\\linewidth", 1, true))
			set_lines_spy:revert()
		end)

		it("should insert after selection if no math block is found and warn once", function()
			local bufnr = vim_test_env.setup_buffer({ "no math here" })
			mock_io.find_math_block_end:returns(nil)
			local selection_end_line = 1
			local set_lines_spy = stub(vim.api, "nvim_buf_set_lines")
			local notify_once_stub = stub(vim, "notify_once")

			plotting_ui.insert_snippet(bufnr, selection_end_line, "plots/myplot_456")

			assert.spy(set_lines_spy).was.called_with(bufnr, 2, 2, false, match.is_table())
			assert.spy(notify_once_stub).was.called(1)
			set_lines_spy:revert()
			notify_once_stub:revert()
		end)

		it("should only warn once even if multiple fallbacks are triggered", function()
			local bufnr = vim_test_env.setup_buffer({ "still no math" })
			mock_io.find_math_block_end:returns(nil)
			local set_lines_spy = stub(vim.api, "nvim_buf_set_lines")
			local notify_once_stub = stub(vim, "notify_once")

			plotting_ui.insert_snippet(bufnr, 0, "plots/first")
			plotting_ui.insert_snippet(bufnr, 0, "plots/second")

			assert.spy(set_lines_spy).was.called(2)
			assert.spy(notify_once_stub).was.called(1)
			set_lines_spy:revert()
			notify_once_stub:revert()
		end)
	end)

	describe("External Viewer", function()
		it("should open the output image in an external viewer when configured", function()
			mock_config.plotting.outputmode = "viewer"
			local plot_path = "/tmp/plot.pdf"

			plotting_ui.handle_output(plot_path)

			assert.spy(mock_async.run_job).was.called(1)
			local cmd = mock_async.run_job.calls[1].vals[1]
			assert.are.same(mock_config.plotting.viewer_cmd_pdf, cmd[1])
			assert.are.same(plot_path, cmd[2])
		end)

		it("should use open", function()
			local plot_path = "test.png"
			setup_test_environment()
			plotting_ui.handle_output(plot_path)
			assert.are.same("open", mock_async.run_job.calls[1].vals[1][1])
		end)

		it("should raise E_VIEWER_FAILED if the viewer command fails", function()
			mock_config.plotting.outputmode = "viewer"
			mock_async.run_job = function(_cmd, opts)
				opts.on_exit(127, "", "command not found")
			end

			plotting_ui.handle_output("/tmp/plot.pdf")

			assert
				.spy(mock_error_handler.notify_error).was
				.called_with("Plot Viewer", mock_error_handler.E_VIEWER_FAILED, nil, nil, "command not found")
		end)
	end)

	describe("Advanced Config UI", function()
		local original_api
		local original_vim_ui_input
		local mock_bufnr = 100
		local mock_winid = 200
		local buffer_lines

		before_each(function()
			original_api = {
				nvim_create_buf = vim.api.nvim_create_buf,
				nvim_buf_set_lines = vim.api.nvim_buf_set_lines,
				nvim_open_win = vim.api.nvim_open_win,
				nvim_create_autocmd = vim.api.nvim_create_autocmd,
				nvim_buf_get_lines = vim.api.nvim_buf_get_lines,
			}
			original_vim_ui_input = vim.ui.input
			vim.api.nvim_create_buf = stub.new(vim.api, "nvim_create_buf", function()
				return mock_bufnr
			end)
			vim.api.nvim_buf_set_lines = stub.new(vim.api, "nvim_buf_set_lines", function(_, _, _, _, lines)
				buffer_lines = vim.deepcopy(lines)
			end)
			vim.api.nvim_open_win = stub.new(vim.api, "nvim_open_win", function()
				return mock_winid
			end)
			vim.api.nvim_create_autocmd = stub.new(vim.api, "nvim_create_autocmd")
			vim.api.nvim_buf_get_lines = stub.new(vim.api, "nvim_buf_get_lines", function()
				return vim.deepcopy(buffer_lines or {})
			end)
			vim.ui.input = stub.new(vim.ui, "input", function(_, on_confirm)
				if on_confirm then
					on_confirm("y")
				end
			end)
		end)

		after_each(function()
			vim.api.nvim_create_buf = original_api.nvim_create_buf
			vim.api.nvim_buf_set_lines = original_api.nvim_buf_set_lines
			vim.api.nvim_open_win = original_api.nvim_open_win
			vim.api.nvim_create_autocmd = original_api.nvim_create_autocmd
			vim.api.nvim_buf_get_lines = original_api.nvim_buf_get_lines
			vim.ui.input = original_vim_ui_input
		end)

		local function set_field(lines, key, value)
			for i, line in ipairs(lines) do
				if line:match("^" .. key:gsub("%-", "%%-") .. ":%s*") then
					lines[i] = string.format("%s: %s", key, value)
					return
				end
			end
		end

		local function set_series_field(lines, series_index, key, value)
			local current_series
			for i, line in ipairs(lines) do
				local idx = line:match("^%-%-%-%s*Series%s+(%d+)%s*:")
				if idx then
					current_series = tonumber(idx)
				elseif current_series == series_index and line:match("^" .. key:gsub("%-", "%%-") .. ":%s*") then
					lines[i] = string.format("%s: %s", key, value)
					return
				end
			end
		end

		it("should open a config buffer pre-filled with defaults", function()
			plotting_ui.open_advanced_config({})
			assert.spy(vim.api.nvim_create_buf).was.called(1)
			assert.spy(vim.api.nvim_open_win).was.called(1)
			assert.spy(vim.api.nvim_buf_set_lines).was.called(1)
			local buffer_content = vim.api.nvim_buf_set_lines.calls[1].vals[5]
			assert.is_table(buffer_content)
			assert.truthy(table.concat(buffer_content, "\n"):find("Form: explicit"))
		end)

		it("should auto-select the plot form based on input classification", function()
			plotting_ui.open_advanced_config({ classification = { form = "polar" } })
			local buffer_content = vim.api.nvim_buf_set_lines.calls[1].vals[5]
			assert.truthy(table.concat(buffer_content, "\n"):find("Form: polar"))
		end)

		it("should include fields for ranges, scales, and style options", function()
			plotting_ui.open_advanced_config({ classification = { dim = 2 }, series = { { ast = "f(x)" } } })
			local content = table.concat(vim.api.nvim_buf_set_lines.calls[1].vals[5], "\n")
			assert.truthy(content:find("X%-range:"))
			assert.truthy(content:find("Y%-range:"))
			assert.falsy(content:find("Z%-range:"))
			assert.truthy(content:find("Grid: on"))
			assert.truthy(content:find("X-scale: linear"))
			assert.truthy(content:find("Color:"))
			assert.truthy(content:find("Linewidth:"))
			assert.truthy(content:find("Linestyle:"))
			assert.truthy(content:find("Marker:"))
			assert.truthy(content:find("Markersize:"))
			assert.truthy(content:find("Alpha:"))
		end)

		it("should create separate sections for each series", function()
			plotting_ui.open_advanced_config({ series = { { ast = "sin(x)" }, { ast = "cos(x)" } } })
			local content = table.concat(vim.api.nvim_buf_set_lines.calls[1].vals[5], "\n")
			assert.truthy(content:find("--- Series 1: sin%p+x%p- ---"))
			assert.truthy(content:find("--- Series 2: cos%p+x%p- ---"))
			assert.truthy(content:find("Color:"))
			assert.truthy(content:find("Linewidth:"))
		end)

		it("should trigger a plot on :wq and cancel on :q", function()
			plotting_ui.open_advanced_config({})
			local wq_callback, q_callback

			for _, call in ipairs(vim.api.nvim_create_autocmd.calls) do
				if call.vals[1] == "BufWriteCmd" then
					wq_callback = call.vals[2].callback
				elseif call.vals[1] == "BufWipeout" then
					q_callback = call.vals[2].callback
				end
			end

			assert.is_function(wq_callback, "BufWriteCmd callback was not defined.")
			assert.is_function(q_callback, "BufWipeout callback was not defined.")

			wq_callback()
			assert.spy(vim.ui.input).was.called(1)
			assert.spy(mock_plotting_core.initiate_plot).was.called(1)

			mock_plotting_core.initiate_plot:clear()
			q_callback()
			assert.spy(mock_plotting_core.initiate_plot).was_not.called()
		end)

		it("should only plot when the user confirms", function()
			plotting_ui.open_advanced_config({})
			local wq_callback

			for _, call in ipairs(vim.api.nvim_create_autocmd.calls) do
				if call.vals[1] == "BufWriteCmd" then
					wq_callback = call.vals[2].callback
				end
			end

			vim.ui.input = stub.new(vim.ui, "input", function(_, on_confirm)
				if on_confirm then
					on_confirm(nil)
				end
			end)

			wq_callback()
			assert.spy(mock_plotting_core.initiate_plot).was_not_called()
		end)

		it("should parse buffer edits into plotting options", function()
			local classification = {
				form = "explicit",
				dim = 2,
				series = {
					{
						ast = "sin(x)",
						dependent_vars = { "y" },
						independent_vars = { "x" },
					},
				},
			}
			plotting_ui.open_advanced_config({
				classification = classification,
				series = classification.series,
				expression = "sin(x)",
			})

			local wq_callback
			for _, call in ipairs(vim.api.nvim_create_autocmd.calls) do
				if call.vals[1] == "BufWriteCmd" then
					wq_callback = call.vals[2].callback
				end
			end

			assert.is_function(wq_callback)

			local defaults = vim.deepcopy(vim.api.nvim_buf_set_lines.calls[1].vals[5])
			local mutated = vim.deepcopy(defaults)
			set_field(mutated, "Backend", "python")
			set_field(mutated, "Output mode", "viewer")
			set_field(mutated, "Legend", "off")
			set_field(mutated, "Legend placement", "upper left")
			set_field(mutated, "X-range", "[0, 5]")
			set_field(mutated, "Grid", "off")
			set_field(mutated, "Colorbar", "on")
			set_series_field(mutated, 1, "Color", "red")
			set_series_field(mutated, 1, "Linewidth", "3.5")
			set_series_field(mutated, 1, "Alpha", "0.5")
			buffer_lines = mutated

			mock_options_builder.build = stub.new(mock_options_builder, "build", function(classification_arg, overrides)
				assert.are.same(classification, classification_arg)
				local base = {
					dim = classification_arg.dim,
					form = classification_arg.form,
					backend = "wolfram",
					outputmode = "latex",
					legend_auto = true,
					legend_pos = "best",
					grids = true,
					colorbar = false,
					series = { {} },
				}
				if overrides then
					for k, v in pairs(overrides) do
						base[k] = v
					end
				end
				return base
			end)

			wq_callback()

			assert.spy(mock_options_builder.build).was.called(1)
			assert.spy(mock_plotting_core.initiate_plot).was.called(1)
			local final_opts = mock_plotting_core.initiate_plot.calls[1].vals[1]
			assert.are.same("python", final_opts.backend)
			assert.are.same("viewer", final_opts.outputmode)
			assert.is_false(final_opts.legend_auto)
			assert.are.same("upper left", final_opts.legend_pos)
			assert.are.same({ 0, 5 }, final_opts.xrange)
			assert.is_false(final_opts.grids)
			assert.is_true(final_opts.colorbar)
			assert.are.same("red", final_opts.series[1].color)
			assert.are.same(3.5, final_opts.series[1].linewidth)
			assert.are.same(0.5, final_opts.series[1].alpha)
			assert.are.same("sin(x)", final_opts.expression)
		end)

		it("should allow dependents to be reset for recomputation", function()
			local classification = {
				form = "explicit",
				dim = 2,
				dependent_vars = { "y" },
				series = {
					{
						ast = "sin(x)",
						dependent_vars = { "y" },
						independent_vars = { "x" },
					},
				},
			}

			plotting_ui.open_advanced_config({
				classification = classification,
				series = classification.series,
				dependent_vars = { "y" },
			})

			local wq_callback
			for _, call in ipairs(vim.api.nvim_create_autocmd.calls) do
				if call.vals[1] == "BufWriteCmd" then
					wq_callback = call.vals[2].callback
				end
			end

			assert.is_function(wq_callback)

			local defaults = vim.deepcopy(vim.api.nvim_buf_set_lines.calls[1].vals[5])
			local mutated = vim.deepcopy(defaults)
			set_field(mutated, "Dependents", "")
			set_series_field(mutated, 1, "Dependents", "auto")
			buffer_lines = mutated

			mock_options_builder.build = stub.new(mock_options_builder, "build", function(classification_arg, overrides)
				assert.are.same(classification, classification_arg)
				if overrides then
					assert.is_nil(overrides.dependents_mode)
				end
				return {
					dim = classification_arg.dim,
					form = classification_arg.form,
					dependent_vars = { "y" },
					series = {
						{
							dependent_vars = { "y" },
						},
					},
				}
			end)

			wq_callback()

			assert.spy(mock_error_handler.notify_error).was_not_called()
			assert.spy(mock_plotting_core.initiate_plot).was.called(1)
			local final_opts = mock_plotting_core.initiate_plot.calls[1].vals[1]
			assert.is_nil(final_opts.dependent_vars)
			assert.is_nil(final_opts.series[1].dependent_vars)
		end)

		it("should report an error when the form conflicts with the classification", function()
			local classification = { form = "explicit", dim = 2 }
			plotting_ui.open_advanced_config({ classification = classification })

			local wq_callback
			for _, call in ipairs(vim.api.nvim_create_autocmd.calls) do
				if call.vals[1] == "BufWriteCmd" then
					wq_callback = call.vals[2].callback
				end
			end

			assert.is_function(wq_callback)

			local defaults = vim.deepcopy(vim.api.nvim_buf_set_lines.calls[1].vals[5])
			local mutated = vim.deepcopy(defaults)
			set_field(mutated, "Form", "polar")
			buffer_lines = mutated

			wq_callback()

			assert.spy(mock_error_handler.notify_error).was.called()
			assert.spy(mock_options_builder.build).was_not.called()
			assert.spy(mock_plotting_core.initiate_plot).was_not_called()
		end)
	end)

	describe("Miscellaneous UX", function()
		it("should automatically enable a legend for multiple series", function()
			local plot_opts = plotting_ui.build_final_opts_from_classification({
				series = { { ast = "s1" }, { ast = "s2" } },
				dim = 2,
				form = "explicit",
			})
			assert.is_true(plot_opts.legend_auto)
		end)

		it("should NOT automatically enable a legend for a single series with no label", function()
			local plot_opts = plotting_ui.build_final_opts_from_classification({
				series = { { ast = "s1" } },
				dim = 2,
				form = "explicit",
			})
			assert.is_false(plot_opts.legend_auto)
		end)

		it("should enable legend for a single series if a label is provided", function()
			local plot_opts = plotting_ui.build_final_opts_from_classification({
				series = { { ast = "s1", label = "My Function" } },
				dim = 2,
				form = "explicit",
			})
			assert.is_true(plot_opts.legend_auto)
		end)

		it("should use generic default labels if none are provided for multiple series", function()
			local plot_opts = plotting_ui.build_final_opts_from_classification({
				series = { { ast = "s1" }, { ast = "s2" } },
				dim = 2,
				form = "explicit",
			})
			assert.are.same("Series 1", plot_opts.series[1].label)
			assert.are.same("Series 2", plot_opts.series[2].label)
		end)
	end)
end)
