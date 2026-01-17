-- tests/unit/backends/python/linear_algebra_spec.lua
-- Unit tests for the Python handlers in the linear algebra domain.

local spy = require("luassert.spy")
local linear_algebra_python_handlers

describe("Tungsten Linear Algebra Domain Python Handlers", function()
	local handlers
	local mock_recur_render

	local function ast_node(type, props)
		props = props or {}
		props.type = type
		return props
	end

	before_each(function()
		package.loaded["tungsten.backends.python.domains.linear_algebra"] = nil
		linear_algebra_python_handlers = require("tungsten.backends.python.domains.linear_algebra")
		handlers = linear_algebra_python_handlers.handlers

		mock_recur_render = spy.new(function(child_node)
			if not child_node or type(child_node) ~= "table" then
				return tostring(child_node)
			end

			if child_node.type == "number" then
				return tostring(child_node.value)
			end
			if child_node.type == "variable" then
				return child_node.name
			end
			if child_node.type == "matrix_placeholder" then
				return child_node.name or "GenericMatrix"
			end
			if child_node.type == "vector_placeholder" then
				return child_node.name or "GenericVector"
			end
			if child_node.type == "expr_placeholder" then
				return child_node.content or "GenericExpression"
			end

			return "rendered(" .. child_node.type .. ")"
		end)
	end)

	describe("matrix_to_vector_str", function()
		it("renders empty matrix as Matrix([])", function()
			local node = ast_node("matrix", { rows = {} })
			local result = linear_algebra_python_handlers.matrix_to_vector_str(node, mock_recur_render)
			assert.are.equal("Matrix([])", result)
		end)

		it("renders row matrix as a vector", function()
			local node = ast_node("matrix", {
				rows = {
					{ ast_node("number", { value = 1 }), ast_node("number", { value = 2 }) },
				},
			})
			local result = linear_algebra_python_handlers.matrix_to_vector_str(node, mock_recur_render)
			assert.are.equal("Matrix([1, 2])", result)
		end)

		it("renders column matrix as a vector", function()
			local node = ast_node("matrix", {
				rows = {
					{ ast_node("variable", { name = "x" }) },
					{ ast_node("variable", { name = "y" }) },
				},
			})
			local result = linear_algebra_python_handlers.matrix_to_vector_str(node, mock_recur_render)
			assert.are.equal("Matrix([x, y])", result)
		end)

		it("falls back to render for non-matrix input", function()
			local node = ast_node("variable", { name = "v" })
			local result = linear_algebra_python_handlers.matrix_to_vector_str(node, mock_recur_render)
			assert.are.equal("v", result)
		end)
	end)

	describe("matrix handler", function()
		it("renders a 2x2 matrix", function()
			local node = ast_node("matrix", {
				rows = {
					{ ast_node("number", { value = 1 }), ast_node("variable", { name = "a" }) },
					{ ast_node("variable", { name = "b" }), ast_node("number", { value = 2 }) },
				},
			})
			local result = handlers.matrix(node, mock_recur_render)
			assert.are.equal("Matrix([[1, a], [b, 2]])", result)
		end)
	end)

	describe("vector handler", function()
		it("renders simple vector", function()
			local node = ast_node("vector", {
				elements = {
					ast_node("variable", { name = "v1" }),
					ast_node("number", { value = 5 }),
					ast_node("variable", { name = "v3" }),
				},
				orientation = "column",
			})
			local result = handlers.vector(node, mock_recur_render)
			assert.are.equal("Matrix([v1, 5, v3])", result)
		end)
	end)

	describe("determinant handler", function()
		it("formats determinant", function()
			local matrix_expr_node = ast_node("expr_placeholder", { content = "M" })
			local node = ast_node("determinant", { expression = matrix_expr_node })
			local result = handlers.determinant(node, mock_recur_render)
			assert.are.equal("sp.det(M)", result)
		end)

		it("falls back to absolute value for non-matrix expressions", function()
			local scalar_expr_node = ast_node("variable", { name = "x" })
			local node = ast_node("determinant", { expression = scalar_expr_node })
			local result = handlers.determinant(node, mock_recur_render)
			assert.are.equal("sp.Abs(x)", result)
		end)
	end)

	describe("dot_product handler", function()
		it("formats dot product", function()
			local vec1_node = ast_node("vector_placeholder", { name = "u" })
			local vec2_node = ast_node("vector_placeholder", { name = "v" })
			local node = ast_node("dot_product", { left = vec1_node, right = vec2_node })
			local result = handlers.dot_product(node, mock_recur_render)
			assert.are.equal("(u).dot(v)", result)
		end)
	end)

	describe("norm handler", function()
		it("uses matrix norm with p-value", function()
			local expr_node = ast_node("vector_placeholder", { name = "v" })
			local node = ast_node("norm", {
				expression = expr_node,
				p_value = ast_node("number", { value = 2 }),
			})
			local result = handlers.norm(node, mock_recur_render)
			assert.are.equal("(v).norm(2)", result)
		end)

		it("uses absolute value for non-matrix expressions", function()
			local expr_node = ast_node("number", { value = 9 })
			local node = ast_node("norm", { expression = expr_node })
			local result = handlers.norm(node, mock_recur_render)
			assert.are.equal("sp.Abs(9)", result)
		end)
	end)

	describe("matrix and vector utilities", function()
		it("renders matrix power", function()
			local node = ast_node("matrix_power", {
				base = ast_node("expr_placeholder", { content = "A" }),
				exponent = ast_node("number", { value = 3 }),
			})
			local result = handlers.matrix_power(node, mock_recur_render)
			assert.are.equal("sp.Matrix(A) ** 3", result)
		end)

		it("renders identity and zero matrix helpers", function()
			local identity_node = ast_node("identity_matrix", { dimension = ast_node("number", { value = 4 }) })
			local zero_node =
				ast_node("zero_vector_matrix", { dimensions = ast_node("expr_placeholder", { content = "2, 3" }) })

			assert.are.equal("sp.eye(4)", handlers.identity_matrix(identity_node, mock_recur_render))
			assert.are.equal("sp.zeros(2, 3)", handlers.zero_vector_matrix(zero_node, mock_recur_render))
		end)

		it("renders gaussian elimination", function()
			local node = ast_node("gauss_eliminate", { expression = ast_node("expr_placeholder", { content = "M" }) })
			local result = handlers.gauss_eliminate(node, mock_recur_render)
			assert.are.equal("sp.Matrix(M).rref()[1]", result)
		end)
	end)

	describe("vector_list handler", function()
		it("formats a list of vectors", function()
			local node = ast_node("vector_list", {
				vectors = {
					ast_node("vector_placeholder", { name = "u" }),
					ast_node("matrix", { rows = { { ast_node("number", { value = 1 }) } } }),
				},
			})
			local result = handlers.vector_list(node, mock_recur_render)
			assert.are.equal("[u, Matrix([1])]", result)
		end)
	end)

	describe("linear_independent_test handler", function()
		it("handles vector list with matrix vectors", function()
			local node = ast_node("linear_independent_test", {
				target = ast_node("vector_list", {
					vectors = {
						ast_node("matrix", {
							rows = {
								{ ast_node("number", { value = 1 }), ast_node("number", { value = 2 }) },
							},
						}),
						ast_node("matrix", {
							rows = {
								{ ast_node("variable", { name = "x" }) },
								{ ast_node("variable", { name = "y" }) },
							},
						}),
					},
				}),
			})

			local result = handlers.linear_independent_test(node, mock_recur_render)
			assert.are.equal(
				"sp.Matrix.hstack([Matrix([1, 2]), Matrix([x, y])]).rank() == len([Matrix([1, 2]), Matrix([x, y])])",
				result
			)
		end)

		it("logs warning for unexpected target types", function()
			local logger = require("tungsten.util.logger")
			local original_warn = logger.warn
			local warn_spy = spy.new(function() end)
			logger.warn = warn_spy

			local node = ast_node("linear_independent_test", {
				target = ast_node("expr_placeholder", { content = "K" }),
			})
			local result = handlers.linear_independent_test(node, mock_recur_render)
			assert.are.equal("sp.Matrix.hstack(K).rank() == len(K)", result)
			assert.spy(warn_spy).was.called()
			logger.warn = original_warn
		end)
	end)
end)
