local mock_utils = require("tests.helpers.mock_utils")
local vim_test_env = require("tests.helpers.vim_test_env")

local plotting_ui
local mock_error_handler

local function setup_test_environment()
	vim_test_env.clear_jobstart_handlers()
	mock_utils.reset_modules({
		"tungsten.ui.plotting",
		"tungsten.core.plotting",
		"tungsten.util.error_handler",
		"tungsten.state",
		"tungsten.config",
		"tungsten.util.async",
		"tungsten.ui.io",
		"tungsten.domains.plotting.options_builder",
		"tungsten.core.parser",
		"tungsten.core.engine",
		"tungsten.backends.manager",
	})

	mock_utils.create_empty_mock_module("tungsten.core.plotting", { "initiate_plot", "get_undefined_symbols" })
	mock_error_handler = mock_utils.create_empty_mock_module("tungsten.util.error_handler", { "notify_error" })
	mock_error_handler.E_BAD_OPTS = "E_BAD_OPTS"
	mock_error_handler.E_BACKEND_UNAVAILABLE = "E_BACKEND_UNAVAILABLE"
	package.loaded["tungsten.state"] = { persistent_variables = {} }
	package.loaded["tungsten.config"] = { plotting = {} }
	mock_utils.create_empty_mock_module("tungsten.util.async", { "run_job" })
	mock_utils.create_empty_mock_module("tungsten.ui.io", { "find_math_block_end" })
	mock_utils.create_empty_mock_module("tungsten.domains.plotting.options_builder", { "build" })
	mock_utils.create_empty_mock_module("tungsten.core.parser", { "parse" })
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

	it("enforces missing keys after parsing", function()
		local helpers = plotting_ui._advanced_helpers
		local ok = helpers.ensure_all_keys_present({ Form = true }, {}, { { Label = true } }, {}, { {} })
		assert.False(ok)
		assert.equal(1, #mock_error_handler.notify_error.calls)
	end)
end)
