-- Unit tests for the plot classification logic.

local mock_utils = require("tests.helpers.mock_utils")

describe("Plot Classification Logic", function()
	local classification
	local free_vars
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

		mock_ast = {
			create_variable_node = function(name)
				return ast_node("variable", { name = name })
			end,
		}
		package.loaded["tungsten.core.ast"] = mock_ast

		classification = require("tungsten.domains.plotting.classification")
		free_vars = require("tungsten.domains.plotting.free_vars")
	end)

	it("should classify a single-variable expression f(x) as a 2D explicit plot", function()
		local expr = ast_node("function_call", { name = "sin", args = { "x" } })
		free_vars.find = function()
			return { "x" }
		end

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
		free_vars.find = function()
			return { "x", "y" }
		end

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
		free_vars.find = function()
			return { "x" }
		end

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

		free_vars.find = function()
			return { "x", "y" }
		end

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

		free_vars.find = function()
			return { "t" }
		end

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

		free_vars.find = function()
			return { "u", "v" }
		end

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

		free_vars.find = function()
			return { "theta" }
		end

		local result, err = classification.analyze(polar)

		assert.is_nil(err)
		assert.are.same({
			dim = 2,
			form = "polar",
			series = { { kind = "function", ast = polar, independent_vars = { "theta" }, dependent_vars = { "r" } } },
		}, result)
	end)

	it("errors when Polar2D uses a non-theta variable", function()
		local polar = ast_node("Polar2D", { r = "1+cos(phi)" })

		free_vars.find = function()
			return { "phi" }
		end

		local result, err = classification.analyze(polar)

		assert.is_nil(result)
		assert.are.equal("E_MIXED_COORD_SYS", err.code)
	end)

	it("should classify inequality expressions as region plots", function()
		local inequality = ast_node("inequality", { lhs = "x^2+y^2", op = "<", rhs = "1" })

		free_vars.find = function()
			return { "x", "y" }
		end

		local result, err = classification.analyze(inequality)

		assert.is_nil(err)
		assert.are.same({
			dim = 2,
			form = "implicit",
			series = {
				{
					kind = "inequality",
					ast = inequality,
					independent_vars = { "x", "y" },
					dependent_vars = {},
				},
			},
		}, result)
	end)

	it("should default to a 2D contour plot for an expression with two free variables in simple mode", function()
		local expr = ast_node("binary", { op = "+", left = "x^2", right = "y^2" })
		free_vars.find = function()
			return { "x", "y" }
		end

		local result, err = classification.analyze(expr, { mode = "simple" })

		assert.is_nil(err)
		assert.are.same({
			dim = 2,
			form = "implicit",
			series = { { kind = "function", ast = expr, independent_vars = { "x", "y" }, dependent_vars = {} } },
		}, result)
	end)

	it("treats (expr, expr) as a point in simple mode", function()
		local point = ast_node("Point2", { x = ast_node("number", { value = 1 }), y = ast_node("number", { value = 2 }) })
		local result, err = classification.analyze(point, { mode = "simple" })

		assert.is_nil(err)
		assert.are.same({
			dim = 2,
			form = "explicit",
			series = { { kind = "points", points = { point } } },
		}, result)
	end)

	it("treats (f(t), g(t)) as parametric in advanced mode", function()
		local tvar = mock_ast.create_variable_node("t")
		local point = ast_node("Point2", {
			x = ast_node("function_call", { name = "f", args = { tvar } }),
			y = ast_node("function_call", { name = "g", args = { tvar } }),
		})
		free_vars.find = function()
			return { "t" }
		end

		local result, err = classification.analyze(point, { mode = "advanced", form = "parametric" })

		assert.is_nil(err)
		assert.are.same({
			dim = 2,
			form = "parametric",
			series = { { kind = "function", ast = point, independent_vars = { "t" }, dependent_vars = { "x", "y" } } },
		}, result)
	end)

	it("treats (u, v, u+v) as parametric in advanced mode", function()
		local u = mock_ast.create_variable_node("u")
		local v = mock_ast.create_variable_node("v")
		local point = ast_node("Point3", {
			x = u,
			y = v,
			z = ast_node("binary", { op = "+", left = u, right = v }),
		})
		free_vars.find = function()
			return { "u", "v" }
		end

		local result, err = classification.analyze(point, { mode = "advanced", form = "parametric" })

		assert.is_nil(err)
		assert.are.same({
			dim = 3,
			form = "parametric",
			series = {
				{ kind = "function", ast = point, independent_vars = { "u", "v" }, dependent_vars = { "x", "y", "z" } },
			},
		}, result)
	end)

	it("treats (r(theta), theta) as polar in advanced mode", function()
		local theta = mock_ast.create_variable_node("theta")
		local point = ast_node("Point2", {
			x = ast_node("function_call", { name = "h", args = { theta } }),
			y = theta,
		})
		free_vars.find = function()
			return { "theta" }
		end

		local result, err = classification.analyze(point, { mode = "advanced", form = "polar" })

		assert.is_nil(err)
		assert.are.same({
			dim = 2,
			form = "polar",
			series = { { kind = "function", ast = point, independent_vars = { "theta" }, dependent_vars = { "r" } } },
		}, result)
	end)

	it("errors on (r(theta), theta+1) in polar advanced mode", function()
		local theta = mock_ast.create_variable_node("theta")
		local point = ast_node("Point2", {
			x = ast_node("function_call", { name = "h", args = { theta } }),
			y = ast_node("binary", { left = theta, op = "+", right = ast_node("number", { value = 1 }) }),
		})
		free_vars.find = function()
			return { "theta" }
		end

		local result, err = classification.analyze(point, { mode = "advanced", form = "polar" })

		assert.is_nil(result)
		assert.are.equal("E_MIXED_COORD_SYS", err.code)
	end)

	it("merges consecutive Point3 nodes into one scatter series", function()
		local p1 = ast_node("Point3", { x = 1, y = 2, z = 3 })
		local p2 = ast_node("point_3d", { x = 4, y = 5, z = 6 })
		local seq = ast_node("sequence", { p1, p2 })

		local result, err = classification.analyze(seq)

		assert.is_nil(err)
		assert.are.same({
			dim = 3,
			form = "explicit",
			series = { { kind = "points", points = { p1, p2 } } },
		}, result)
	end)

	describe("Error Handling", function()
		it("should throw an error if multiple expressions have mixed dimensions", function()
			local series = ast_node("sequence", {
				ast_node("function_call", { name = "sin" }),
				ast_node("binary", { op = "*", left = "x", right = "y" }),
			})

			local call = 0
			free_vars.find = function()
				call = call + 1
				if call == 1 then
					return { "x" }
				else
					return { "x", "y" }
				end
			end

			local result, err = classification.analyze(series)
			assert.is_nil(result)
			assert.are.equal("E_MIXED_DIMENSIONS", err.code)
		end)

		it("should throw an error if polar and Cartesian expressions are mixed", function()
			local series = ast_node("sequence", {
				ast_node("polar_2d", { r = "theta" }),
				ast_node("function_call", { name = "sin" }),
			})
			free_vars.find = function()
				return { "x" }
			end

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

			free_vars.find = function()
				return { "x" }
			end

			local result, err = classification.analyze(series)
			assert.is_nil(result)
			assert.are.equal("E_MIXED_DIMENSIONS", err.code)
		end)
	end)
end)
