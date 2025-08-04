-- tests/unit/backends/python/differential_equations_spec.lua
-- Tests for Python differential equation handlers.

describe("Differential Equations Python Handlers", function()
	local handlers
	local mock_render

	before_each(function()
		handlers = require("tungsten.backends.python.domains.differential_equations").handlers

		mock_render = function(node)
			if not node or not node.type then
				return ""
			end

			if node.type == "variable" then
				return node.name
			elseif node.type == "function_call" then
				local arg_str = ""
				if node.args and #node.args > 0 then
					local rendered_args = {}
					for _, arg in ipairs(node.args) do
						table.insert(rendered_args, mock_render(arg))
					end
					arg_str = table.concat(rendered_args, ", ")
				end
				return mock_render(node.name_node) .. "(" .. arg_str .. ")"
			elseif node.type == "derivative" then
				local var_name = node.variable.name or "y"
				local indep_var = (node.independent_variable and node.independent_variable.name) or "x"
				return "sp.diff(" .. var_name .. "(" .. indep_var .. "), " .. indep_var .. ")"
			end
			return ""
		end
	end)

	describe("ode handler", function()
		it("generates dsolve for single ODE", function()
			local ast = {
				type = "ode",
				lhs = { type = "derivative", variable = { type = "variable", name = "y" } },
				rhs = { type = "variable", name = "y" },
			}
			local result = handlers.ode(ast, mock_render)
			assert.are.same("sp.dsolve(sp.Eq(sp.diff(y(x), x), y))", result)
		end)
	end)

	describe("ode_system handler", function()
		it("generates dsolve for system", function()
			local ast = {
				type = "ode_system",
				equations = {
					{
						type = "ode",
						lhs = { type = "derivative", variable = { type = "variable", name = "y" } },
						rhs = { type = "variable", name = "z" },
					},
					{
						type = "ode",
						lhs = { type = "derivative", variable = { type = "variable", name = "z" } },
						rhs = { type = "variable", name = "y" },
					},
				},
			}
			local result = handlers.ode_system(ast, mock_render)
			assert.is_true(
				result == "sp.dsolve([sp.Eq(sp.diff(y(x), x), z), sp.Eq(sp.diff(z(x), x), y)])"
					or result == "sp.dsolve([sp.Eq(sp.diff(z(x), x), y), sp.Eq(sp.diff(y(x), x), z)])"
			)
		end)
	end)

	describe("wronskian handler", function()
		it("formats wronskian", function()
			local ast = {
				type = "wronskian",
				functions = {
					{ type = "variable", name = "f" },
					{ type = "variable", name = "g" },
				},
			}
			local result = handlers.wronskian(ast, mock_render)
			assert.are.same("sp.wronskian([f, g], x)", result)
		end)
	end)

	describe("laplace_transform handler", function()
		it("formats laplace transform", function()
			local ast = {
				type = "laplace_transform",
				expression = {
					type = "function_call",
					name_node = { type = "variable", name = "f" },
					args = { { type = "variable", name = "t" } },
				},
			}
			local result = handlers.laplace_transform(ast, mock_render)
			assert.are.same("sp.laplace_transform(f(t), t, s)", result)
		end)
	end)

	describe("inverse_laplace_transform handler", function()
		it("formats inverse laplace transform", function()
			local ast = {
				type = "inverse_laplace_transform",
				expression = {
					type = "function_call",
					name_node = { type = "variable", name = "F" },
					args = { { type = "variable", name = "s" } },
				},
			}
			local result = handlers.inverse_laplace_transform(ast, mock_render)
			assert.are.same("sp.inverse_laplace_transform(F(s), s, t)", result)
		end)
	end)

	describe("convolution handler", function()
		it("formats convolution", function()
			local ast = {
				type = "convolution",
				left = { type = "variable", name = "f" },
				right = { type = "variable", name = "g" },
			}
			local result = handlers.convolution(ast, mock_render)
			assert.are.same("sp.convolution(f, g, t, y)", result)
		end)
	end)
end)
