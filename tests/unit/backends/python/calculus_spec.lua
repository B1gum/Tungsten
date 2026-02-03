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

		local string_mt = getmetatable("")
		if string_mt and string_mt.__index and string_mt.__index.table == nil then
			string_mt.__index.table = table
		end

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
			if child_node.type == "symbol" then
				return handlers.symbol(child_node)
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

	describe("limit handler", function()
		it("formats limit expressions", function()
			local node = ast_node("limit", {
				expression = ast_node("variable", { name = "f" }),
				variable = ast_node("variable", { name = "x" }),
				point = ast_node("number", { value = 0 }),
			})

			local result = handlers.limit(node, mock_recur_render)

			assert.are.equal("sp.limit(f, x, 0)", result)
			assert.spy(mock_recur_render).was.called_with(node.expression)
			assert.spy(mock_recur_render).was.called_with(node.variable)
			assert.spy(mock_recur_render).was.called_with(node.point)
		end)
	end)

	describe("integral handlers", function()
		it("formats indefinite integrals", function()
			local node = ast_node("indefinite_integral", {
				integrand = ast_node("variable", { name = "g" }),
				variable = ast_node("variable", { name = "t" }),
			})

			local result = handlers.indefinite_integral(node, mock_recur_render)

			assert.are.equal("sp.integrate(g, t)", result)
			assert.spy(mock_recur_render).was.called_with(node.integrand)
			assert.spy(mock_recur_render).was.called_with(node.variable)
		end)

		it("formats definite integrals", function()
			local node = ast_node("definite_integral", {
				integrand = ast_node("variable", { name = "h" }),
				variable = ast_node("variable", { name = "u" }),
				lower_bound = ast_node("number", { value = -1 }),
				upper_bound = ast_node("symbol", { name = "infinity" }),
			})

			local result = handlers.definite_integral(node, mock_recur_render)

			assert.are.equal("sp.integrate(h, (u, -1, sp.oo))", result)
			assert.spy(mock_recur_render).was.called_with(node.integrand)
			assert.spy(mock_recur_render).was.called_with(node.variable)
			assert.spy(mock_recur_render).was.called_with(node.lower_bound)
			assert.spy(mock_recur_render).was.called_with(node.upper_bound)
		end)
	end)

	describe("summation handler", function()
		it("formats summations", function()
			local node = ast_node("summation", {
				body_expression = ast_node("variable", { name = "term" }),
				index_variable = ast_node("variable", { name = "n" }),
				start_expression = ast_node("number", { value = 1 }),
				end_expression = ast_node("number", { value = 5 }),
			})

			local result = handlers.summation(node, mock_recur_render)

			assert.are.equal("sp.summation(term, (n, 1, 5))", result)
			assert.spy(mock_recur_render).was.called_with(node.body_expression)
			assert.spy(mock_recur_render).was.called_with(node.index_variable)
			assert.spy(mock_recur_render).was.called_with(node.start_expression)
			assert.spy(mock_recur_render).was.called_with(node.end_expression)
		end)
	end)

	describe("product handler", function()
		it("formats products", function()
			local node = ast_node("product", {
				body_expression = ast_node("variable", { name = "term" }),
				index_variable = ast_node("variable", { name = "n" }),
				start_expression = ast_node("number", { value = 1 }),
				end_expression = ast_node("number", { value = 5 }),
			})

			local result = handlers.product(node, mock_recur_render)

			assert.are.equal("sp.product(term, (n, 1, 5))", result)
			assert.spy(mock_recur_render).was.called_with(node.body_expression)
			assert.spy(mock_recur_render).was.called_with(node.index_variable)
			assert.spy(mock_recur_render).was.called_with(node.start_expression)
			assert.spy(mock_recur_render).was.called_with(node.end_expression)
		end)
	end)

	describe("symbol handler", function()
		it("maps infinity and pi", function()
			assert.are.equal("sp.oo", handlers.symbol(ast_node("symbol", { name = "infinity" })))
			assert.are.equal("sp.pi", handlers.symbol(ast_node("symbol", { name = "pi" })))
		end)

		it("returns the symbol name when not mapped", function()
			assert.are.equal("gamma", handlers.symbol(ast_node("symbol", { name = "gamma" })))
		end)
	end)
end)
