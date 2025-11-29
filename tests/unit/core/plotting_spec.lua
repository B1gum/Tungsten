local mock_utils = require("tests.helpers.mock_utils")

describe("core.plotting.get_undefined_symbols", function()
	local core
	local state
	local classification

	local function var(name)
		return { type = "variable", name = name }
	end

	local function binary(op, left, right)
		return { type = "binary", operator = op, left = left, right = right }
	end

	local function call(name, args)
		return {
			type = "function_call",
			name_node = { type = "variable", name = name },
			args = args,
		}
	end

	before_each(function()
		mock_utils.reset_modules({ "tungsten.core.plotting" })
		core = require("tungsten.core.plotting")
		classification = require("tungsten.domains.plotting.classification")
		state = require("tungsten.state")
		state.persistent_variables = {}
	end)

	it("ignores axis variables when no additional symbols are present", function()
		local ast = call("sin", { var("x") })
		local ok, symbols = core.get_undefined_symbols({ ast = ast })
		assert.is_true(ok)
		assert.are.same({}, symbols)
	end)

	it("detects scalar parameters that require definitions", function()
		local ast = call("sin", { binary("*", var("k"), var("x")) })
		local _, symbols = core.get_undefined_symbols({ ast = ast })
		assert.are.same({ { name = "k", type = "variable" } }, symbols)
	end)

	it("ignores names that already exist in persistent variables", function()
		state.persistent_variables = { k = "2" }
		local ast = call("sin", { binary("*", var("k"), var("x")) })
		local _, symbols = core.get_undefined_symbols({ ast = ast })
		assert.are.same({}, symbols)
	end)

	it("detects dependent functions", function()
		local ast = call("f", { var("x") })
		local _, symbols = core.get_undefined_symbols({ ast = ast })
		assert.are.same({ { name = "f(x)", type = "function" } }, symbols)
	end)

	it("marks pattern-based names as points when dimension hints request it", function()
		local _, symbols = core.get_undefined_symbols({ ast = var("p0"), dim = 3 })
		assert.are.same({ { name = "p0", type = "point", point_dim = 3, requires_point3 = true } }, symbols)
	end)
end)

describe("core.plotting helper steps", function()
	local core
	local classification

	local function var(name)
		return { type = "variable", name = name }
	end

	local function call(name, args)
		return {
			type = "function_call",
			name_node = { type = "variable", name = name },
			args = args,
		}
	end

	before_each(function()
		mock_utils.reset_modules({ "tungsten.core.plotting" })
		core = require("tungsten.core.plotting")
		classification = require("tungsten.domains.plotting.classification")
	end)

	it("parses and normalizes ASTs into node lists", function()
		local nodes = core._parse_and_normalize_ast({ ast = { type = "Sequence", nodes = { var("x"), var("y") } } })
		assert.are.same({ var("x"), var("y") }, nodes)
	end)

	it("discovers defined functions from equality expressions", function()
		local nodes = { { type = "Equality", lhs = call("f", { var("x") }) } }
		local defined = core._discover_defined_symbols({}, nodes)
		assert.is_true(defined["f(x)"])
		assert.is_true(defined["f"])
	end)

	it("picks the highest detected plot dimension", function()
		local original = classification.analyze
		classification.analyze = function(node)
			if node.type == "variable" and node.name == "p0" then
				return { dim = 2 }
			end
			return { dim = 3 }
		end
		local nodes = { var("p0"), var("p1") }
		local plot_dim = core._determine_plot_dimension({}, nodes)
		classification.analyze = original
		assert.are.equal(3, plot_dim)
	end)

	it("collects undefined entries while honoring axis overrides and ignored functions", function()
		local nodes = { call("sin", { var("r"), var("k") }), call("g", { var("x") }) }
		local defined = core._discover_defined_symbols({}, nodes)
		local ignored = { ["g(x)"] = true, g = true }
		local entries = core._collect_undefined_entries({}, nodes, defined, ignored, { r = true }, nil)
		assert.are.same({ { name = "k", type = "variable" } }, entries)
	end)

	it("returns mixed variable and function requirements", function()
		local nodes = { { type = "binary", operator = "*", left = call("f", { var("x") }), right = var("k") } }
		local defined = core._discover_defined_symbols({}, nodes)
		local ignored = {}
		local entries = core._collect_undefined_entries({}, nodes, defined, ignored, nil, nil)
		assert.are.same({ { name = "k", type = "variable" }, { name = "f(x)", type = "function" } }, entries)
	end)
end)
