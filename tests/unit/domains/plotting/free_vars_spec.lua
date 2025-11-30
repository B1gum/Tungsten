local ast = require("tungsten.core.ast")
local free_vars = require("tungsten.domains.plotting.free_vars")

describe("free variable detection", function()
	it("finds variables in a simple expression", function()
		local x = ast.create_variable_node("x")
		local y = ast.create_variable_node("y")
		local expr = ast.create_binary_operation_node("+", x, y)
		assert.are.same({ "x", "y" }, free_vars.find(expr))
	end)

	it("excludes bound variables in integrals", function()
		local x = ast.create_variable_node("x")
		local y = ast.create_variable_node("y")
		local integrand = ast.create_binary_operation_node("*", x, y)
		local integral = ast.create_indefinite_integral_node(integrand, x)
		assert.are.same({ "y" }, free_vars.find(integral))
	end)

	it("handles definite integrals with bounds", function()
		local x = ast.create_variable_node("x")
		local y = ast.create_variable_node("y")
		local z = ast.create_variable_node("z")
		local integrand = ast.create_binary_operation_node("*", x, y)
		local integral = ast.create_definite_integral_node(integrand, x, ast.create_number_node(0), z)
		assert.are.same({ "y", "z" }, free_vars.find(integral))
	end)

	it("accounts for bindings introduced by summations, limits, and derivatives", function()
		local start_expr = ast.create_variable_node("a")
		local end_expr = ast.create_function_call_node(ast.create_variable_node("f"), {
			ast.create_variable_node("b"),
		})

		local summation = ast.create_summation_node(
			ast.create_variable_node("i"),
			start_expr,
			end_expr,
			ast.create_binary_operation_node("*", ast.create_variable_node("i"), ast.create_variable_node("c"))
		)

		local limit = ast.create_limit_node(
			ast.create_variable_node("x"),
			ast.create_number_node(0),
			ast.create_function_call_node(ast.create_variable_node("g"), {
				ast.create_variable_node("d"),
			})
		)

		local ordinary = ast.create_ordinary_derivative_node(
			ast.create_number_node(1),
			ast.create_variable_node("t"),
			ast.create_number_node(2)
		)

		local partial = ast.create_partial_derivative_node(
			ast.create_variable_node("p"),
			{ ast.create_variable_node("u"), ast.create_variable_node("v") },
			ast.create_variable_node("m")
		)

		local expr = ast.create_function_call_node(ast.create_variable_node("wrapper"), {
			summation,
			limit,
			ordinary,
			partial,
			ast.create_constant_node("π"),
		})

		assert.are.same({ "a", "b", "c", "d", "p", "t", "u", "v" }, free_vars.find(expr))
	end)
end)
