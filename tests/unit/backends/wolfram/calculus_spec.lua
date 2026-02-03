-- tests/unit/domains/calculus/wolfram_handlers_spec.lua
-- Unit tests for the Wolfram handlers in the calculus domain.

local spy = require("luassert.spy")
local calculus_wolfram_handlers

describe("Tungsten Calculus Domain Wolfram Handlers", function()
	local handlers
	local mock_recur_render

	local function ast_node(type, props)
		props = props or {}
		props.type = type
		return props
	end

	before_each(function()
		package.loaded["tungsten.backends.wolfram.domains.calculus"] = nil
		calculus_wolfram_handlers = require("tungsten.backends.wolfram.domains.calculus")

		handlers = calculus_wolfram_handlers.handlers

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
				if handlers and handlers.symbol then
					return handlers.symbol(child_node, mock_recur_render)
				else
					if child_node.name == "infinity" then
						return "Infinity"
					end
					if child_node.name == "pi" then
						return "Pi"
					end
					return child_node.name
				end
			end

			return "rendered(" .. child_node.type .. ":" .. (child_node.name or child_node.value or "complex") .. ")"
		end)
	end)

	describe("ordinary_derivative handler", function()
		it("should correctly format a first-order ordinary derivative", function()
			local node = ast_node("ordinary_derivative", {
				expression = ast_node("variable", { name = "fx" }),
				variable = ast_node("variable", { name = "x" }),
				order = ast_node("number", { value = 1 }),
			})
			local result = handlers.ordinary_derivative(node, mock_recur_render)
			assert.are.equal("D[fx, x]", result)
			assert.spy(mock_recur_render).was.called_with(node.expression)
			assert.spy(mock_recur_render).was.called_with(node.variable)
			assert.spy(mock_recur_render).was.called_with(node.order)
		end)

		it("should correctly format a higher-order ordinary derivative", function()
			local node = ast_node("ordinary_derivative", {
				expression = ast_node("variable", { name = "gy" }),
				variable = ast_node("variable", { name = "y" }),
				order = ast_node("number", { value = 3 }),
			})
			local result = handlers.ordinary_derivative(node, mock_recur_render)
			assert.are.equal("D[gy, {y, 3}]", result)
		end)

		it("should correctly format a higher-order ordinary derivative with variable order", function()
			local node = ast_node("ordinary_derivative", {
				expression = ast_node("variable", { name = "hz" }),
				variable = ast_node("variable", { name = "z" }),
				order = ast_node("variable", { name = "n" }),
			})
			local result = handlers.ordinary_derivative(node, mock_recur_render)
			assert.are.equal("D[hz, {z, n}]", result)
		end)

		it("uses prime notation for derivatives of explicit function calls", function()
			local node = ast_node("ordinary_derivative", {
				expression = ast_node("function_call", {
					name_node = ast_node("variable", { name = "y" }),
					args = { ast_node("variable", { name = "x" }) },
				}),
				variable = ast_node("variable", { name = "x" }),
				order = ast_node("number", { value = 1 }),
			})

			local result = handlers.ordinary_derivative(node, mock_recur_render)

			assert.are.equal("Y'[x]", result)
		end)

		it("uses D notation when differentiating multi-argument functions", function()
			local node = ast_node("ordinary_derivative", {
				expression = ast_node("function_call", {
					name_node = ast_node("variable", { name = "y" }),
					args = {
						ast_node("variable", { name = "t" }),
						ast_node("variable", { name = "x" }),
					},
				}),
				variable = ast_node("variable", { name = "t" }),
				order = ast_node("number", { value = 1 }),
			})

			local result = handlers.ordinary_derivative(node, mock_recur_render)

			assert.are.equal("D[Y[t, x], t]", result)
		end)
	end)

	describe("partial_derivative handler", function()
		it("should correctly format a first-order partial derivative with one variable", function()
			local node = ast_node("partial_derivative", {
				expression = ast_node("variable", { name = "fxy" }),
				overall_order = ast_node("number", { value = 1 }),
				variables = {
					ast_node("differentiation_term", {
						variable = ast_node("variable", { name = "x" }),
						order = ast_node("number", { value = 1 }),
					}),
				},
			})
			local result = handlers.partial_derivative(node, mock_recur_render)
			assert.are.equal("D[fxy, x]", result)
			assert.spy(mock_recur_render).was.called_with(node.expression)
			assert.spy(mock_recur_render).was.called_with(node.variables[1].variable)
			assert.spy(mock_recur_render).was.called_with(node.variables[1].order)
		end)

		it("should correctly format a higher-order partial derivative with one variable", function()
			local node = ast_node("partial_derivative", {
				expression = ast_node("variable", { name = "gxyz" }),
				overall_order = ast_node("number", { value = 2 }),
				variables = {
					ast_node("differentiation_term", {
						variable = ast_node("variable", { name = "y" }),
						order = ast_node("number", { value = 2 }),
					}),
				},
			})
			local result = handlers.partial_derivative(node, mock_recur_render)
			assert.are.equal("D[gxyz, {y, 2}]", result)
		end)

		it("should correctly format a mixed-order partial derivative with multiple variables", function()
			local node = ast_node("partial_derivative", {
				expression = ast_node("variable", { name = "h" }),
				overall_order = ast_node("number", { value = 3 }),
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
			assert.are.equal("D[h, x, {y, 2}]", result)
		end)

		it("should correctly format with multiple first-order variables", function()
			local node = ast_node("partial_derivative", {
				expression = ast_node("variable", { name = "psi" }),
				overall_order = ast_node("number", { value = 2 }),
				variables = {
					ast_node("differentiation_term", {
						variable = ast_node("variable", { name = "x" }),
						order = ast_node("number", { value = 1 }),
					}),
					ast_node("differentiation_term", {
						variable = ast_node("variable", { name = "t" }),
						order = ast_node("number", { value = 1 }),
					}),
				},
			})
			local result = handlers.partial_derivative(node, mock_recur_render)
			assert.are.equal("D[psi, x, t]", result)
		end)
	end)

	describe("limit handler", function()
		it("should correctly format a limit expression", function()
			local node = ast_node("limit", {
				expression = ast_node("variable", { name = "fx" }),
				variable = ast_node("variable", { name = "x" }),
				point = ast_node("number", { value = 0 }),
			})
			local result = handlers.limit(node, mock_recur_render)
			assert.are.equal("Limit[fx, x -> 0]", result)
			assert.spy(mock_recur_render).was.called_with(node.expression)
			assert.spy(mock_recur_render).was.called_with(node.variable)
			assert.spy(mock_recur_render).was.called_with(node.point)
		end)

		it("should correctly format a limit with variable point", function()
			local node = ast_node("limit", {
				expression = ast_node("variable", { name = "gx" }),
				variable = ast_node("variable", { name = "x" }),
				point = ast_node("variable", { name = "a" }),
			})
			local result = handlers.limit(node, mock_recur_render)
			assert.are.equal("Limit[gx, x -> a]", result)
		end)

		it("should correctly format a limit approaching Infinity", function()
			local node = ast_node("limit", {
				expression = ast_node("variable", { name = "hx" }),
				variable = ast_node("variable", { name = "x" }),
				point = ast_node("symbol", { name = "infinity" }),
			})
			local result = handlers.limit(node, mock_recur_render)
			assert.are.equal("Limit[hx, x -> Infinity]", result)
		end)
	end)

	describe("indefinite_integral handler", function()
		it("should correctly format an indefinite integral", function()
			local node = ast_node("indefinite_integral", {
				integrand = ast_node("variable", { name = "fx" }),
				variable = ast_node("variable", { name = "x" }),
			})
			local result = handlers.indefinite_integral(node, mock_recur_render)
			assert.are.equal("Integrate[fx, x]", result)
			assert.spy(mock_recur_render).was.called_with(node.integrand)
			assert.spy(mock_recur_render).was.called_with(node.variable)
		end)
	end)

	describe("definite_integral handler", function()
		it("should correctly format a definite integral with numeric bounds", function()
			local node = ast_node("definite_integral", {
				integrand = ast_node("variable", { name = "gx" }),
				variable = ast_node("variable", { name = "x" }),
				lower_bound = ast_node("number", { value = 0 }),
				upper_bound = ast_node("number", { value = 1 }),
			})
			local result = handlers.definite_integral(node, mock_recur_render)
			assert.are.equal("Integrate[gx, {x, 0, 1}]", result)
			assert.spy(mock_recur_render).was.called_with(node.integrand)
			assert.spy(mock_recur_render).was.called_with(node.variable)
			assert.spy(mock_recur_render).was.called_with(node.lower_bound)
			assert.spy(mock_recur_render).was.called_with(node.upper_bound)
		end)

		it("should correctly format a definite integral with variable bounds", function()
			local node = ast_node("definite_integral", {
				integrand = ast_node("variable", { name = "hx" }),
				variable = ast_node("variable", { name = "t" }),
				lower_bound = ast_node("variable", { name = "a" }),
				upper_bound = ast_node("variable", { name = "b" }),
			})
			local result = handlers.definite_integral(node, mock_recur_render)
			assert.are.equal("Integrate[hx, {t, a, b}]", result)
		end)

		it("should correctly format a definite integral with symbolic bounds (Infinity)", function()
			local node = ast_node("definite_integral", {
				integrand = ast_node("variable", { name = "psi_x" }),
				variable = ast_node("variable", { name = "x" }),
				lower_bound = ast_node("symbol", { name = "infinity" }),
				upper_bound = ast_node("symbol", { name = "infinity" }),
			})
			local result = handlers.definite_integral(node, mock_recur_render)
			assert.are.equal("Integrate[psi_x, {x, Infinity, Infinity}]", result)
		end)
	end)

	describe("summation handler", function()
		it("should correctly format a summation with numeric iterator bounds", function()
			local node = ast_node("summation", {
				body_expression = ast_node("variable", { name = "ai" }),
				index_variable = ast_node("variable", { name = "i" }),
				start_expression = ast_node("number", { value = 1 }),
				end_expression = ast_node("number", { value = 10 }),
			})
			local result = handlers.summation(node, mock_recur_render)
			assert.are.equal("Sum[ai, {i, 1, 10}]", result)
			assert.spy(mock_recur_render).was.called_with(node.body_expression)
			assert.spy(mock_recur_render).was.called_with(node.index_variable)
			assert.spy(mock_recur_render).was.called_with(node.start_expression)
			assert.spy(mock_recur_render).was.called_with(node.end_expression)
		end)

		it("should correctly format a summation with variable iterator bounds", function()
			local node = ast_node("summation", {
				body_expression = ast_node("variable", { name = "xk" }),
				index_variable = ast_node("variable", { name = "k" }),
				start_expression = ast_node("variable", { name = "m" }),
				end_expression = ast_node("variable", { name = "N" }),
			})
			local result = handlers.summation(node, mock_recur_render)
			assert.are.equal("Sum[xk, {k, m, N}]", result)
		end)

		it("should correctly format a summation with symbolic upper bound (Infinity)", function()
			local node = ast_node("summation", {
				body_expression = ast_node("variable", { name = "term_n" }),
				index_variable = ast_node("variable", { name = "n" }),
				start_expression = ast_node("number", { value = 0 }),
				end_expression = ast_node("symbol", { name = "infinity" }),
			})
			local result = handlers.summation(node, mock_recur_render)
			assert.are.equal("Sum[term_n, {n, 0, Infinity}]", result)
		end)
	end)

	describe("product handler", function()
		it("should correctly format a product with numeric iterator bounds", function()
			local node = ast_node("product", {
				body_expression = ast_node("variable", { name = "ai" }),
				index_variable = ast_node("variable", { name = "i" }),
				start_expression = ast_node("number", { value = 1 }),
				end_expression = ast_node("number", { value = 10 }),
			})
			local result = handlers.product(node, mock_recur_render)
			assert.are.equal("Product[ai, {i, 1, 10}]", result)
			assert.spy(mock_recur_render).was.called_with(node.body_expression)
			assert.spy(mock_recur_render).was.called_with(node.index_variable)
			assert.spy(mock_recur_render).was.called_with(node.start_expression)
			assert.spy(mock_recur_render).was.called_with(node.end_expression)
		end)

		it("should correctly format a product with variable iterator bounds", function()
			local node = ast_node("product", {
				body_expression = ast_node("variable", { name = "xk" }),
				index_variable = ast_node("variable", { name = "k" }),
				start_expression = ast_node("variable", { name = "m" }),
				end_expression = ast_node("variable", { name = "N" }),
			})
			local result = handlers.product(node, mock_recur_render)
			assert.are.equal("Product[xk, {k, m, N}]", result)
		end)

		it("should correctly format a product with symbolic upper bound (Infinity)", function()
			local node = ast_node("product", {
				body_expression = ast_node("variable", { name = "term_n" }),
				index_variable = ast_node("variable", { name = "n" }),
				start_expression = ast_node("number", { value = 0 }),
				end_expression = ast_node("symbol", { name = "infinity" }),
			})
			local result = handlers.product(node, mock_recur_render)
			assert.are.equal("Product[term_n, {n, 0, Infinity}]", result)
		end)
	end)

	describe("symbol handler", function()
		it("should handle 'infinity'", function()
			local node = ast_node("symbol", { name = "infinity" })
			assert.is_function(handlers.symbol, "handlers.symbol is not a function or is nil")
			local result = handlers.symbol(node, mock_recur_render)
			assert.are.equal("Infinity", result)
		end)

		it("should handle 'pi'", function()
			local node = ast_node("symbol", { name = "pi" })
			assert.is_function(handlers.symbol, "handlers.symbol is not a function or is nil")
			local result = handlers.symbol(node, mock_recur_render)
			assert.are.equal("Pi", result)
		end)

		it("should return name for unrecognized symbols", function()
			local node = ast_node("symbol", { name = "gamma_const" })
			assert.is_function(handlers.symbol, "handlers.symbol is not a function or is nil")
			local result = handlers.symbol(node, mock_recur_render)
			assert.are.equal("gamma_const", result)
		end)
	end)
end)
