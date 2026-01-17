local mock_utils = require("tests.helpers.mock_utils")
local stub = require("luassert.stub")
local vim_test_env = require("tests.helpers.vim_test_env")

local plotting_ui
local mock_error_handler
local mock_parser

local function setup_test_environment()
	vim_test_env.clear_jobstart_handlers()
	mock_utils.reset_modules({
		"tungsten.ui.plotting",
		"tungsten.domains.plotting.analysis",
		"tungsten.util.error_handler",
		"tungsten.state",
		"tungsten.config",
		"tungsten.util.async",
		"tungsten.domains.plotting.io",
		"tungsten.domains.plotting.options_builder",
		"tungsten.core.parser",
		"tungsten.core.engine",
		"tungsten.backends.manager",
	})

	mock_utils.create_empty_mock_module(
		"tungsten.domains.plotting.analysis",
		{ "initiate_plot", "get_undefined_symbols" }
	)
	mock_error_handler = mock_utils.create_empty_mock_module("tungsten.util.error_handler", { "notify_error" })
	mock_error_handler.E_BAD_OPTS = "E_BAD_OPTS"
	mock_error_handler.E_BACKEND_UNAVAILABLE = "E_BACKEND_UNAVAILABLE"
	package.loaded["tungsten.state"] = { persistent_variables = {} }
	package.loaded["tungsten.config"] = { plotting = {} }
	mock_utils.create_empty_mock_module("tungsten.util.async", { "run_job" })
	mock_utils.create_empty_mock_module("tungsten.domains.plotting.io", { "find_math_block_end" })
	mock_utils.create_empty_mock_module("tungsten.domains.plotting.options_builder", { "build" })
	mock_parser = mock_utils.create_empty_mock_module("tungsten.core.parser", { "parse" })
	mock_utils.create_empty_mock_module("tungsten.core.engine", { "evaluate_async" })
	mock_utils.create_empty_mock_module("tungsten.backends.manager", { "current" })

	plotting_ui = require("tungsten.ui.plotting")
end

describe("Advanced buffer helpers", function()
	before_each(setup_test_environment)

	it("builds expected key sets based on form and dimension", function()
		local helpers = plotting_ui._advanced_helpers
		local globals, series = helpers.build_expected_keys(3, "parametric", {
			{ kind = "points" },
			{ kind = "line" },
		}, true)

		assert.True(globals["Colormap"])
		assert.True(globals["U-range"])
		assert.True(globals["V-range"])
		assert.True(globals["View elevation"])
		assert.True(series[1]["Marker"])
		assert.is_nil(series[2]["Marker"])
	end)

	it("rejects dependents overrides that conflict with expectations", function()
		local helpers = plotting_ui._advanced_helpers
		local target = {}
		local ok = helpers.apply_dependents_override(target, "z", "x", "Series 1")
		assert.False(ok)
		assert.equal(1, #mock_error_handler.notify_error.calls)
	end)

	it("parses series line updates and sets overrides", function()
		local helpers = plotting_ui._advanced_helpers
		local series_overrides = { [1] = {} }
		local seen_series = { [1] = {} }
		local ctx = {
			series_idx = 1,
			expected_series_keys = { [1] = { Label = true, Dependents = true, Linewidth = true } },
			seen_series_keys = seen_series,
			series_overrides = series_overrides,
			expected_series_dependents = { [1] = "y" },
		}

		local ok_label = helpers.parse_series_line("Label", "My Series", ctx)
		local ok_dependents = helpers.parse_series_line("Dependents", "auto", ctx)
		local ok_width = helpers.parse_series_line("Linewidth", "2.5", ctx)

		assert.True(ok_label)
		assert.True(ok_dependents)
		assert.True(ok_width)
		assert.same({ Label = true, Dependents = true, Linewidth = true }, seen_series[1])
		assert.same({ label = "My Series", dependents_mode = "auto", linewidth = 2.5 }, series_overrides[1])
	end)

	it("parses global line updates, including ranges and toggles", function()
		local helpers = plotting_ui._advanced_helpers
		local overrides = {}
		local seen = {}
		mock_parser.parse = stub.new(mock_parser, "parse", function(expr)
			return { series = { { source = expr } } }
		end)
		local ctx = {
			classification = {},
			allowed_forms = { explicit = true },
			allowed_backends = { wolfram = true },
			allowed_output_modes = { latex = true },
			overrides = overrides,
			expected_global_keys = { ["Legend"] = true, ["Grid"] = true, ["X-range"] = true },
			seen_global_keys = seen,
			expected_dependents = "y",
		}

		assert.True(helpers.parse_global_line("Legend", "auto", ctx))
		assert.True(helpers.parse_global_line("Grid", "off", ctx))
		assert.True(helpers.parse_global_line("X-range", "[a, b]", ctx))

		assert.True(seen["Legend"])
		assert.True(seen["Grid"])
		assert.True(seen["X-range"])
		assert.is_true(overrides.legend_auto)
		assert.is_false(overrides.grids)
		assert.are.same("a", overrides.xrange[1].source)
		assert.are.same("b", overrides.xrange[2].source)
	end)

	it("rejects invalid alpha values in series overrides", function()
		local helpers = plotting_ui._advanced_helpers
		local series_overrides = { [1] = {} }
		local seen_series = { [1] = {} }
		local ctx = {
			series_idx = 1,
			expected_series_keys = { [1] = { Alpha = true } },
			seen_series_keys = seen_series,
			series_overrides = series_overrides,
			expected_series_dependents = { [1] = "y" },
		}

		local ok_alpha = helpers.parse_series_line("Alpha", "1.5", ctx)

		assert.False(ok_alpha)
		assert.equal(1, #mock_error_handler.notify_error.calls)
	end)

	it("rejects invalid range formats for global overrides", function()
		local helpers = plotting_ui._advanced_helpers
		local overrides = {}
		local seen = {}
		local ctx = {
			classification = {},
			allowed_forms = { explicit = true },
			allowed_backends = { wolfram = true },
			allowed_output_modes = { latex = true },
			overrides = overrides,
			expected_global_keys = { ["X-range"] = true },
			seen_global_keys = seen,
			expected_dependents = "y",
		}

		local ok_range = helpers.parse_global_line("X-range", "oops", ctx)

		assert.False(ok_range)
		assert.equal(1, #mock_error_handler.notify_error.calls)
	end)

	it("enforces missing keys after parsing", function()
		local helpers = plotting_ui._advanced_helpers
		local ok = helpers.ensure_all_keys_present({ Form = true }, {}, { { Label = true } }, {}, { {} })
		assert.False(ok)
		assert.equal(1, #mock_error_handler.notify_error.calls)
	end)

	it("parses range endpoints that use expressions", function()
		local helpers = plotting_ui._advanced_helpers
		mock_parser.parse = function(value)
			return { series = { { source = value } } }
		end
		local overrides = {}
		local ctx = {
			classification = {},
			allowed_forms = { explicit = true },
			allowed_backends = { wolfram = true },
			allowed_output_modes = { latex = true },
			overrides = overrides,
			expected_global_keys = { ["X-range"] = true },
			seen_global_keys = {},
			expected_dependents = "y",
		}

		local ok = helpers.parse_global_line("X-range", "[0, pi]", ctx)

		assert.True(ok)
		assert.are.same(0, overrides.xrange[1])
		assert.are.same({ source = "pi" }, overrides.xrange[2])
	end)

	it("rejects invalid alpha values for series entries", function()
		local helpers = plotting_ui._advanced_helpers
		local ctx = {
			series_idx = 1,
			expected_series_keys = { [1] = { Alpha = true } },
			seen_series_keys = { [1] = {} },
			series_overrides = { [1] = {} },
			expected_series_dependents = { [1] = "y" },
		}

		local ok = helpers.parse_series_line("Alpha", "1.2", ctx)

		assert.False(ok)
		assert.equal(1, #mock_error_handler.notify_error.calls)
	end)

	it("marks dependents as auto when blank", function()
		local helpers = plotting_ui._advanced_helpers
		local target = {}

		local ok = helpers.apply_dependents_override(target, "", "x", "Dependents")

		assert.True(ok)
		assert.are.same("auto", target.dependents_mode)
	end)
end)
