local analysis = require("tungsten.domains.plotting.analysis")
local ast = require("tungsten.core.ast")
local state = require("tungsten.state")

describe("plotting analysis", function()
	it("returns empty results when no expression is provided", function()
		local ok, entries = analysis.get_undefined_symbols({ expression = "   " })
		assert.is_true(ok)
		assert.are.same({}, entries)
	end)

	it("normalizes sequence ASTs into node lists", function()
		local seq = ast.create_sequence_node({
			ast.create_variable_node("a"),
			ast.create_variable_node("b"),
		})

		local nodes = analysis._parse_and_normalize_ast({ ast = seq })

		assert.are.same(2, #nodes)
		assert.are.same("a", nodes[1].name)
		assert.are.same("b", nodes[2].name)
	end)

	it("discovers defined symbols from state and equality definitions", function()
		local previous_persistent = state.persistent_variables
		state.persistent_variables = { PERSIST = true }

		local equality = ast.create_equality_node(
			ast.create_function_call_node(ast.create_variable_node("f"), { ast.create_variable_node("x") }),
			ast.create_variable_node("x")
		)

		local defined = analysis._discover_defined_symbols({
			definitions = { alpha = true, __order = {} },
		}, { equality })

		assert.is_true(defined.PERSIST)
		assert.is_true(defined.alpha)
		assert.is_true(defined["f(x)"])
		assert.is_true(defined.f)

		state.persistent_variables = previous_persistent
	end)

	it("prefers the highest plot dimension from analyzed nodes", function()
		local expr = ast.create_binary_operation_node(
			"+",
			ast.create_binary_operation_node("+", ast.create_variable_node("x"), ast.create_variable_node("y")),
			ast.create_variable_node("z")
		)

		local dim = analysis._determine_plot_dimension({ dim = 2 }, { expr })

		assert.are.same(4, dim)
	end)

	it("collects points, variables, and functions while honoring ignored symbols", function()
		local seq = ast.create_sequence_node({
			ast.create_variable_node("P1"),
			ast.create_variable_node("u"),
			ast.create_function_call_node(ast.create_variable_node("g"), { ast.create_variable_node("a") }),
			ast.create_function_call_node(ast.create_variable_node("sin"), { ast.create_variable_node("b") }),
		})

		local ok, entries = analysis.get_undefined_symbols({
			ast = seq,
			expected_dim = 3,
			axis_names = { u = true },
			ignore_symbols = { "b" },
		})

		assert.is_true(ok)
		assert.are.same({
			{ name = "P1", type = "point", point_dim = 3, requires_point3 = true },
			{ name = "a", type = "variable" },
			{ name = "g(a)", type = "function" },
		}, entries)
	end)
end)

describe("plotting analysis", function()
	local original_persistent

	before_each(function()
		original_persistent = state.persistent_variables
		state.persistent_variables = {}
	end)

	after_each(function()
		state.persistent_variables = original_persistent
	end)

	it("normalizes sequence ASTs into node lists", function()
		local seq = ast.create_sequence_node({
			ast.create_variable_node("x"),
			ast.create_variable_node("y"),
		})
		local nodes = analysis._parse_and_normalize_ast({ ast = seq })

		assert.is_table(nodes)
		assert.are.equal(2, #nodes)
		assert.are.equal("variable", nodes[1].type)
		assert.are.equal("x", nodes[1].name)
		assert.are.equal("variable", nodes[2].type)
		assert.are.equal("y", nodes[2].name)
	end)

	it("returns empty results for blank expressions", function()
		local ok, symbols = analysis.get_undefined_symbols({ expression = "  " })

		assert.is_true(ok)
		assert.are.same({}, symbols)
	end)

	it("collects defined symbols from options and equality nodes", function()
		state.persistent_variables = { alpha = true }

		local defined_call = ast.create_function_call_node(ast.create_variable_node("h"), {
			ast.create_variable_node("t"),
		})
		local eq = ast.create_equality_node(defined_call, ast.create_number_node(1))
		local nodes = { eq }

		local defined = analysis._discover_defined_symbols({
			definitions = { beta = {}, __order = { "beta" } },
			defined_symbols = "delta",
			known_symbols = { gamma = true },
		}, nodes)

		assert.is_true(defined.alpha)
		assert.is_true(defined.beta)
	end)

	it("selects the highest plot dimension from classification", function()
		local expr = ast.create_binary_operation_node(
			"+",
			ast.create_binary_operation_node("+", ast.create_variable_node("x"), ast.create_variable_node("y")),
			ast.create_variable_node("z")
		)

		local dim = analysis._determine_plot_dimension({ dim = 2 }, { expr })

		assert.are.equal(4, dim)
	end)

	it("reports undefined points, variables, and functions", function()
		state.persistent_variables = { c = true }

		local expr1 = ast.create_binary_operation_node("+", ast.create_variable_node("x"), ast.create_variable_node("P1"))
		local expr2 = ast.create_binary_operation_node("+", ast.create_variable_node("A"), ast.create_variable_node("q"))
		local expr3 = ast.create_function_call_node(ast.create_variable_node("myfun"), {
			ast.create_variable_node("a"),
			ast.create_variable_node("b"),
		})
		local expr4 = ast.create_function_call_node(ast.create_variable_node("sin"), {
			ast.create_variable_node("c"),
		})
		local expr5 = ast.create_equality_node(
			ast.create_function_call_node(ast.create_variable_node("h"), {
				ast.create_variable_node("t"),
			}),
			ast.create_number_node(1)
		)

		local seq = ast.create_sequence_node({ expr1, expr2, expr3, expr4, expr5 })

		local ok, entries = analysis.get_undefined_symbols({
			ast = seq,
			dim = 3,
			axis_symbols = { "q" },
			point_symbols = { "A" },
			ignore_symbols = { "b" },
			defined_symbols = { "d", "t" },
		})

		assert.is_true(ok)
		assert.are.same({
			{ name = "A", type = "point", point_dim = 3, requires_point3 = true },
			{ name = "P1", type = "point", point_dim = 3, requires_point3 = true },
			{ name = "a", type = "variable" },
			{ name = "q", type = "variable" },
			{ name = "myfun(a,b)", type = "function" },
		}, entries)
	end)
end)
