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
end)
