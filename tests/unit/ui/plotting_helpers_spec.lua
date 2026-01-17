local spy = require("luassert.spy")
local mock_utils = require("tests.helpers.mock_utils")

local plotting_ui
local mock_error_handler
local mock_parser
local mock_engine
local mock_backend_manager

local eval_overrides
local backend_available

local function setup_test_environment()
	mock_utils.reset_modules({
		"tungsten.ui.plotting",
		"tungsten.domains.plotting.analysis",
		"tungsten.util.error_handler",
		"tungsten.state",
		"tungsten.config",
		"tungsten.util.async",
		"tungsten.domains.plotting.io",
		"tungsten.domains.plotting.options_builder",
		"tungsten.domains.plotting.style_parser",
		"tungsten.core.parser",
		"tungsten.core.engine",
		"tungsten.backends.manager",
	})

	mock_utils.create_empty_mock_module("tungsten.domains.plotting.analysis")
	mock_error_handler = mock_utils.create_empty_mock_module("tungsten.util.error_handler", { "notify_error" })
	mock_error_handler.E_BAD_OPTS = "E_BAD_OPTS"
	mock_error_handler.E_BACKEND_UNAVAILABLE = "E_BACKEND_UNAVAILABLE"
	package.loaded["tungsten.state"] = { persistent_variables = {} }
	package.loaded["tungsten.config"] = { plotting = {} }
	mock_utils.create_empty_mock_module("tungsten.util.async")
	mock_utils.create_empty_mock_module("tungsten.domains.plotting.io")
	mock_utils.create_empty_mock_module("tungsten.domains.plotting.options_builder")
	mock_utils.mock_module("tungsten.domains.plotting.style_parser", {
		parse = function()
			return {}
		end,
	})

	eval_overrides = {}
	backend_available = true

	mock_parser = mock_utils.create_empty_mock_module("tungsten.core.parser")
	mock_parser.parse = function(text)
		if text == "bad" then
			error("parse error")
		end
		return { series = { { source = text } } }
	end

	mock_engine = mock_utils.create_empty_mock_module("tungsten.core.engine")
	mock_engine.evaluate_async = function(ast, _, cb)
		local override = eval_overrides[ast and ast.source]
		if override and override.error then
			cb(nil, override.error)
			return
		end
		cb(override and override.output or "", nil)
	end

	mock_backend_manager = mock_utils.create_empty_mock_module("tungsten.backends.manager")
	mock_backend_manager.current = function()
		if backend_available then
			return {}
		end
		return nil
	end

	plotting_ui = require("tungsten.ui.plotting")
end

describe("Plotting helper utilities", function()
	before_each(setup_test_environment)

	it("strips the dependents hint and handles non-strings", function()
		local helpers = plotting_ui._test_helpers
		assert.are.equal("x, y", helpers.strip_dependents_hint("x, y (blank or auto to recompute)"))
		assert.are.equal("auto", helpers.strip_dependents_hint("auto"))
		assert.are.equal(5, helpers.strip_dependents_hint(5))
	end)

	it("parses definitions and preserves order", function()
		local helpers = plotting_ui._test_helpers
		local defs = helpers.parse_definitions("a:= 1\nb:= 2\ninvalid\n:=")
		assert.are.same({ latex = "1" }, defs.a)
		assert.are.same({ latex = "2" }, defs.b)
		assert.are.same({ "a", "b" }, defs.__order)
	end)

	it("parses numeric outputs and tuples", function()
		local helpers = plotting_ui._test_helpers
		assert.are.equal(3, helpers.parse_numeric_result(3))
		assert.are.equal(12.5, helpers.parse_numeric_result(" 12.5 "))
		assert.are.equal(1000, helpers.parse_numeric_result("1\\times10^{3}"))
		assert.are.equal(100, helpers.parse_numeric_result("10^{2}"))
		assert.are.same({ 1, 2, 3 }, helpers.parse_numeric_result("\\left(1,2,3\\right)"))
		assert.is_nil(helpers.parse_numeric_result("(1,2)"))
	end)

	it("normalizes buffer lines and adds assignment delimiters", function()
		local helpers = plotting_ui._test_helpers
		local normalized = helpers.normalize_buffer_lines({
			"Variables:",
			"a",
			"b: 2",
			"",
			"Functions:",
			"f(x)",
		})
		assert.are.equal("a:=\nb:=2\nf(x):=", normalized)
	end)

	it("builds symbol buffers for variables and functions", function()
		local helpers = plotting_ui._test_helpers
		local lines = helpers.populate_symbol_buffer({
			{ name = "a", type = "variable" },
			{ name = "f(x)", type = "function" },
			{ name = "a", type = "variable" },
		})
		assert.are.same({ "Variables:", "a:", "", "Functions:", "f(x):=" }, lines)
		assert.are.same({ "Variables:" }, helpers.populate_symbol_buffer({}))
	end)

	it("detects point3 requirements from symbol metadata", function()
		local helpers = plotting_ui._test_helpers
		assert.is_true(helpers.symbol_requires_point3({ type = "point", dim = 3 }))
		assert.is_true(helpers.symbol_requires_point3({ kind = "point3d" }))
		assert.is_false(helpers.symbol_requires_point3({ type = "point", dim = 2 }))
		assert.is_false(helpers.symbol_requires_point3("nope"))
	end)

	it("collects dependents with defaults and ordering", function()
		local helpers = plotting_ui._test_helpers
		local explicit = helpers.collect_dependents({}, 2, "explicit")
		assert.are.equal("y", explicit)
		local parametric = helpers.collect_dependents({}, 3, "parametric")
		assert.are.equal("x, y, z", parametric)
		local explicit_series = helpers.collect_dependents({ { dependent_vars = { "z", "x" } } }, 3, "explicit")
		assert.are.equal("x, z", explicit_series)
	end)

	it("builds default config lines with series styling", function()
		local helpers = plotting_ui._test_helpers
		local lines = helpers.build_default_lines({
			series = { { ast = "p", kind = "points", label = "Points" } },
		})
		local content = table.concat(lines, "\n")
		assert.is_true(content:find("Legend: auto", 1, true) ~= nil)
		assert.is_true(content:find("Marker:", 1, true) ~= nil)
	end)

	it("parses advanced buffer lines into overrides", function()
		local helpers = plotting_ui._test_helpers
		local opts = {
			classification = { form = "explicit", dim = 2, series = { { ast = "f(x)" } } },
			series = { { ast = "f(x)" } },
		}
		local lines = helpers.build_default_lines(opts)
		for i, line in ipairs(lines) do
			if line:match("^X%-range:") then
				lines[i] = "X-range: [0, x+1]"
			end
		end
		local parsed = helpers.parse_advanced_buffer(lines, opts)
		assert.is_table(parsed)
		assert.are.same({ 0, { source = "x+1" } }, parsed.overrides.xrange)
	end)

	it("rejects invalid range expressions in advanced buffers", function()
		local helpers = plotting_ui._test_helpers
		local opts = {
			classification = { form = "explicit", dim = 2, series = { { ast = "f(x)" } } },
			series = { { ast = "f(x)" } },
		}
		local lines = helpers.build_default_lines(opts)
		for i, line in ipairs(lines) do
			if line:match("^X%-range:") then
				lines[i] = "X-range: [0, bad]"
			end
		end
		local parsed = helpers.parse_advanced_buffer(lines, opts)
		assert.is_nil(parsed)
		assert.is_true(#mock_error_handler.notify_error.calls > 0)
	end)

	it("evaluates definitions in order when backend is available", function()
		local helpers = plotting_ui._test_helpers
		eval_overrides["2"] = { output = "2" }
		eval_overrides["a+1"] = { output = "3" }
		local defs = {
			a = { latex = "2" },
			b = { latex = "a+1" },
			__order = { "a", "b" },
		}
		local on_success = spy.new(function() end)
		helpers.evaluate_definitions(defs, on_success, nil)
		assert.spy(on_success).was.called(1)
		assert.are.equal(2, defs.a.value)
		assert.are.equal(3, defs.b.value)
	end)

	it("reports backend errors when evaluating definitions", function()
		local helpers = plotting_ui._test_helpers
		backend_available = false
		local on_failure = spy.new(function() end)
		helpers.evaluate_definitions({ a = { latex = "2" } }, nil, on_failure)
		assert.spy(on_failure).was.called(1)
	end)
end)
