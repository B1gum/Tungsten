-- Unit tests for the plot classification logic.

local spy = require("luassert.spy")
local mock_utils = require("tests.helpers.mock_utils")

describe("Plot Classification Logic", function()
	local classification
	local mock_free_vars
	local mock_ast

	local function ast_node(type, props)
		props = props or {}
		props.type = type
		return props
	end

	before_each(function()
		mock_utils.reset_modules({
			"tungsten.domains.plotting.classification",
			"tungsten.domains.plotting.free_vars",
			"tungsten.core.ast",
		})

		mock_free_vars = {
			find = spy.new(function()
				return {}
			end),
		}
		package.loaded["tungsten.domains.plotting.free_vars"] = mock_free_vars

		mock_ast = {
			create_variable_node = function(name)
				return ast_node("variable", { name = name })
			end,
		}
		package.loaded["tungsten.core.ast"] = mock_ast

		classification = require("tungsten.domains.plotting.classification")
	end)

	it("should classify a single-variable expression f(x) as a 2D explicit plot", function()
		local expr = ast_node("function_call", { name = "sin", args = { "x" } })
		mock_free_vars.find:returns({ "x" })

		local result, err = classification.analyze(expr)

		assert.is_nil(err)
		assert.are.same({
			dim = 2,
			form = "explicit",
			series = { { kind = "function", ast = expr, independent_vars = { "x" }, dependent_vars = { "y" } } },
		}, result)
	end)

	it("should classify a two-variable expression f(x,y) as a 3D explicit surface", function()
		local expr = ast_node("binary", { op = "+", left = "x^2", right = "y^2" })
		mock_free_vars.find:returns({ "x", "y" })

		local result, err = classification.analyze(expr)

		assert.is_nil(err)
		assert.are.same({
			dim = 3,
			form = "explicit",
			series = { { kind = "function", ast = expr, independent_vars = { "x", "y" }, dependent_vars = { "z" } } },
		}, result)
	end)

	it("should classify equations like y = f(x) as explicit plots", function()
		local rhs = ast_node("function_call", { name = "cos", args = { "x" } })
		local eq = ast_node("equality", { lhs = mock_ast.create_variable_node("y"), rhs = rhs })
		mock_free_vars.find:returns({ "x" })

		local result, err = classification.analyze(eq)

		assert.is_nil(err)
		assert.are.same({
			dim = 2,
			form = "explicit",
			series = { { kind = "function", ast = eq, independent_vars = { "x" }, dependent_vars = { "y" } } },
		}, result)
	end)

	it("should classify implicit equations like x^2 + y^2 = 1 as implicit plots", function()
		local eq = ast_node("equality", { lhs = "x^2+y^2", rhs = "1" })
		mock_free_vars.find:returns({ "x", "y" })

		local result, err = classification.analyze(eq)

		assert.is_nil(err)
		assert.are.same({
			dim = 2,
			form = "implicit",
			series = { { kind = "function", ast = eq, independent_vars = { "x", "y" }, dependent_vars = {} } },
		}, result)
	end)

	it("should recognize Parametric2D nodes", function()
		local para2d = ast_node("Parametric2D", { x = "cos(t)", y = "sin(t)" })
		mock_free_vars.find:on_call(1):returns({ "t" }):on_call(2):returns({ "t" })

		local result, err = classification.analyze(para2d)

		assert.is_nil(err)
		assert.are.same({
			dim = 2,
			form = "parametric",
			series = { { kind = "function", ast = para2d, independent_vars = { "t" }, dependent_vars = { "x", "y" } } },
		}, result)
	end)

	it("should recognize Parametric3D nodes", function()
		local para3d = ast_node("Parametric3D", { x = "u", y = "v", z = "u+v" })
		mock_free_vars.find
			:on_call(1)
			:returns({ "u", "v" })
			:on_call(2)
			:returns({ "u", "v" })
			:on_call(3)
			:returns({ "u", "v" })

		local result, err = classification.analyze(para3d)

		assert.is_nil(err)
		assert.are.same({
			dim = 3,
			form = "parametric",
			series = {
				{ kind = "function", ast = para3d, independent_vars = { "u", "v" }, dependent_vars = { "x", "y", "z" } },
			},
		}, result)
	end)

	it("should recognize Polar2D nodes", function()
		local polar = ast_node("Polar2D", { r = "1+cos(theta)" })
		mock_free_vars.find:returns({ "theta" })

		local result, err = classification.analyze(polar)

		assert.is_nil(err)
		assert.are.same({
			dim = 2,
			form = "polar",
			series = { { kind = "function", ast = polar, independent_vars = { "theta" }, dependent_vars = { "r" } } },
		}, result)
	end)

	it("should classify inequality expressions as region plots", function()
		local inequality = ast_node("inequality", { lhs = "x^2+y^2", op = "<", rhs = "1" })
		mock_free_vars.find:returns({ "x", "y" })

		local result, err = classification.analyze(inequality)

		assert.is_nil(err)
		assert.are.same({
			dim = 2,
			form = "inequality",
			series = { { kind = "function", ast = inequality, independent_vars = { "x", "y" }, dependent_vars = {} } },
		}, result)
	end)

	it("should default to a 2D contour plot for an expression with two free variables in simple mode", function()
		local expr = ast_node("binary", { op = "+", left = "x^2", right = "y^2" })
		mock_free_vars.find:returns({ "x", "y" })

		local result, err = classification.analyze(expr, { simple_mode = true })

		assert.is_nil(err)
		assert.are.same({
			dim = 2,
			form = "implicit",
			series = { { kind = "function", ast = expr, independent_vars = { "x", "y" }, dependent_vars = {} } },
		}, result)
	end)

	describe("Error Handling", function()
		it("should throw an error if multiple expressions have mixed dimensions", function()
			local series = ast_node("sequence", {
				ast_node("function_call", { name = "sin" }),
				ast_node("binary", { op = "*", left = "x", right = "y" }),
			})

			mock_free_vars.find:on_call(1):returns({ "x" }):on_call(2):returns({ "x", "y" })

			local result, err = classification.analyze(series)
			assert.is_nil(result)
			assert.are.equal("E_MIXED_DIMENSIONS", err.code)
		end)

		it("should throw an error if polar and Cartesian expressions are mixed", function()
			local series = ast_node("sequence", {
				ast_node("polar_2d", { r = "theta" }),
				ast_node("function_call", { name = "sin" }),
			})
			mock_free_vars.find:returns({ "x" })

			local result, err = classification.analyze(series)
			assert.is_nil(result)
			assert.are.equal("E_MIXED_COORD_SYS", err.code)
		end)

		it("should produce a hard error for coordinate system mismatches with points", function()
			local series = ast_node("sequence", {
				ast_node("polar_2d", { r = "theta" }),
				ast_node("point_2d", { x = 1, y = 1 }),
			})

			local result, err = classification.analyze(series)
			assert.is_nil(result)
			assert.are.equal("E_MIXED_COORD_SYS", err.code)
		end)

		it("should throw an error for a 3D point in a 2D plot", function()
			local series = ast_node("sequence", {
				ast_node("function_call", { name = "sin" }),
				ast_node("point_3d", { x = 1, y = 1, z = 1 }),
			})
			mock_free_vars.find:returns({ "x" })

			local result, err = classification.analyze(series)
			assert.is_nil(result)
			assert.are.equal("E_MIXED_DIMENSIONS", err.code)
		end)
	end)
end)
