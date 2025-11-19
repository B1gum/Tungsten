local mock_utils = require("tests.helpers.mock_utils")

describe("core.plotting.get_undefined_symbols", function()
	local core
	local state

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
