-- tests/unit/backends/python/calculus_spec.lua
-- Unit tests for the Python handlers in the calculus domain.

local spy = require("luassert.spy")

describe("Tungsten Calculus Domain Python Handlers", function()
	local handlers
	local mock_recur_render

	local function ast_node(type, props)
		props = props or {}
		props.type = type
		return props
	end

	before_each(function()
		package.loaded["tungsten.backends.python.domains.calculus"] = nil
		handlers = require("tungsten.backends.python.domains.calculus").handlers

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
			return "rendered(" .. child_node.type .. ")"
		end)
	end)

	describe("ordinary_derivative handler", function()
		it("formats first-order derivative", function()
			local node = ast_node("ordinary_derivative", {
				expression = ast_node("variable", { name = "f" }),
				variable = ast_node("variable", { name = "x" }),
				order = ast_node("number", { value = 1 }),
			})
			local result = handlers.ordinary_derivative(node, mock_recur_render)
			assert.are.equal("sp.diff(f, x)", result)
			assert.spy(mock_recur_render).was.called_with(node.expression)
			assert.spy(mock_recur_render).was.called_with(node.variable)
			assert.spy(mock_recur_render).was.called_with(node.order)
		end)

		it("formats higher-order derivative", function()
			local node = ast_node("ordinary_derivative", {
				expression = ast_node("variable", { name = "g" }),
				variable = ast_node("variable", { name = "y" }),
				order = ast_node("number", { value = 3 }),
			})
			local result = handlers.ordinary_derivative(node, mock_recur_render)
			assert.are.equal("sp.diff(g, y, 3)", result)
		end)
	end)

	describe("partial_derivative handler", function()
		it("formats mixed partial derivative", function()
			local node = ast_node("partial_derivative", {
				expression = ast_node("variable", { name = "h" }),
				variables = {
					ast_node("differentiation_term", {
						variable = ast_node("variable", { name = "x" }),
						order = ast_node("number", { value = 1 }),
					}),
					ast_node("differentiation_term", {
						variable = ast_node("variable", { name = "y" }),
						order = ast_node("number", { value = 2 }),
					}),
				},
			})
			local result = handlers.partial_derivative(node, mock_recur_render)
			assert.are.equal("sp.diff(h, x, y, 2)", result)
		end)
	end)

	describe("symbol handler", function()
		it("maps infinity and pi", function()
			assert.are.equal("sp.oo", handlers.symbol(ast_node("symbol", { name = "infinity" })))
			assert.are.equal("sp.pi", handlers.symbol(ast_node("symbol", { name = "pi" })))
		end)
	end)
end)
