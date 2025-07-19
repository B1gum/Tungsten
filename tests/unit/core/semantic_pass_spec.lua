-- tests/unit/core/semantic_pass_spec.lua

local ast = require("tungsten.core.ast")
local semantic = require("tungsten.core.semantic_pass")

describe("semantic pass", function()
	it("converts matrix superscript T to transpose", function()
		local input = ast.create_superscript_node({ type = "matrix", id = "A" }, { type = "variable", name = "T" })
		local result = semantic.apply(input)
		local expected = ast.create_transpose_node({ type = "matrix", id = "A" })
		assert.are.same(expected, result)
	end)

	it("converts matrix superscript -1 to inverse", function()
		local input = ast.create_superscript_node({ type = "matrix", id = "A" }, { type = "number", value = -1 })
		local result = semantic.apply(input)
		local expected = ast.create_inverse_node({ type = "matrix", id = "A" })
		assert.are.same(expected, result)
	end)

	it("leaves normal superscript unchanged", function()
		local input = ast.create_superscript_node({ type = "variable", name = "x" }, { type = "number", value = 2 })
		local result = semantic.apply(input)
		assert.are.same(input, result)
	end)

	it("converts vector multiplication to dot product", function()
		local left = { type = "vector", elements = {} }
		local right = { type = "vector", elements = {} }
		local input = ast.create_binary_operation_node("*", left, right)
		local result = semantic.apply(input)
		local expected = ast.create_dot_product_node(left, right)
		assert.are.same(expected, result)
	end)

	it("converts vector \times multiplication to cross product", function()
		local left = { type = "vector", elements = {} }
		local right = { type = "vector", elements = {} }
		local input = ast.create_binary_operation_node("\\times", left, right)
		local result = semantic.apply(input)
		local expected = ast.create_cross_product_node(left, right)
		assert.are.same(expected, result)
	end)
end)
