-- tests/unit/domains/differential_equations/wolfram_handlers_spec.lua
-- Busted tests for the differential equations Wolfram handlers.

describe("Differential Equations Wolfram Handlers", function()
	local handlers
	local mock_render
	local executor
	local handler_manager
	local config
	local default_domains

	before_each(function()
		handlers = require("tungsten.backends.wolfram.domains.differential_equations").handlers
		executor = require("tungsten.backends.wolfram.executor")
		handler_manager = require("tungsten.backends.wolfram.handlers")
		config = require("tungsten.config")
		default_domains = {
			"arithmetic",
			"calculus",
			"linear_algebra",
			"differential_equations",
			"plotting",
			"units",
		}

		mock_render = function(node)
			if not node or not node.type then
				return ""
			end

			if node.type == "variable" then
				return node.name
			elseif node.type == "number" then
				return tostring(node.value)
			elseif node.type == "subscript" then
				return string.format("Subscript[%s, %s]", mock_render(node.base), mock_render(node.subscript))
			elseif node.type == "function_call" then
				local arg_str = ""
				if node.args and #node.args > 0 then
					local rendered_args = {}
					for _, arg in ipairs(node.args) do
						table.insert(rendered_args, mock_render(arg))
					end
					arg_str = table.concat(rendered_args, ", ")
				end
				local func_name = mock_render(node.name_node)
				func_name = func_name:match("^%a") and (func_name:sub(1, 1):upper() .. func_name:sub(2)) or func_name
				return func_name .. "[" .. arg_str .. "]"
			elseif node.type == "derivative" then
				local var_name = node.variable.name or "y"
				local order = node.order or 1
				local order_str = string.rep("'", order)
				local indep_var = (node.independent_variable and node.independent_variable.name) or "x"
				return var_name .. order_str .. "[" .. indep_var .. "]"
			elseif node.type == "ordinary_derivative" then
				local order = (node.order and node.order.value) or 1
				local order_str = string.rep("'", order)
				local indep_var = (node.variable and node.variable.name) or "x"

				if node.expression.type == "function_call" then
					local func_name = mock_render(node.expression.name_node)
					func_name = func_name:match("^%a") and (func_name:sub(1, 1):upper() .. func_name:sub(2)) or func_name
					return func_name .. order_str .. "[" .. mock_render(node.expression.args[1]) .. "]"
				elseif node.expression.type == "variable" then
					return node.expression.name .. order_str .. "[" .. indep_var .. "]"
				end
			end
			return ""
		end
	end)

	describe("ode handler", function()
		it("should generate a full DSolve command for a single ODE", function()
			local ast = {
				type = "ode",
				lhs = { type = "derivative", order = 1, variable = { type = "variable", name = "y" } },
				rhs = { type = "variable", name = "y" },
			}
			local result = handlers.ode(ast, mock_render)
			assert.are.same("DSolve[Y'[x] == Y[x], Y[x], {x}]", result)
		end)

		it("should attach the independent variable to bare dependent variables", function()
			local ast = {
				type = "ode",
				lhs = {
					type = "ordinary_derivative",
					expression = { type = "variable", name = "y" },
					variable = { type = "variable", name = "x" },
					order = { type = "number", value = 2 },
				},
				rhs = { type = "variable", name = "y" },
			}

			local result = handlers.ode(ast, mock_render)

			assert.are.same("DSolve[Y''[x] == Y[x], Y[x], {x}]", result)
		end)
	end)

	describe("pde rendering", function()
		before_each(function()
			config.domains = vim.deepcopy(default_domains)
			handler_manager.load_handlers()
		end)

		it("includes all independent variables when derivatives mix variables", function()
			local ast = {
				type = "ode",
				lhs = {
					type = "binary",
					operator = "+",
					left = {
						type = "ordinary_derivative",
						expression = { type = "variable", name = "y" },
						variable = { type = "variable", name = "t" },
						order = { type = "number", value = 1 },
					},
					right = {
						type = "ordinary_derivative",
						expression = { type = "variable", name = "y" },
						variable = { type = "variable", name = "x" },
						order = { type = "number", value = 1 },
					},
				},
				rhs = { type = "number", value = 0 },
			}

			local result = executor.ast_to_code(ast)

			local function has_all_args(str)
				return str:match("%[t%s*,%s*x%]") or str:match("%[x%s*,%s*t%]")
			end

			assert.is_truthy(result:match("D%[%s*[%w_]+%s*%[%s*[tx]%s*,%s*[tx]%s*%]%s*,%s*t%s*%]"))
			assert.is_truthy(result:match("D%[%s*[%w_]+%s*%[%s*[tx]%s*,%s*[tx]%s*%]%s*,%s*x%s*%]"))
			assert.is_truthy(has_all_args(result))
			assert.is_truthy(result:match("DSolve"))
		end)
	end)

	describe("ode_system handler", function()
		it("should generate a full DSolve command for a system of ODEs", function()
			local ast = {
				type = "ode_system",
				equations = {
					{
						type = "ode",
						lhs = { type = "derivative", order = 1, variable = { type = "variable", name = "y" } },
						rhs = { type = "variable", name = "z" },
					},
					{
						type = "ode",
						lhs = { type = "derivative", order = 1, variable = { type = "variable", name = "z" } },
						rhs = { type = "variable", name = "y" },
					},
				},
			}
			local result = handlers.ode_system(ast, mock_render)
			assert.is_true(
				result == "DSolve[{Y'[x] == Z[x], Z'[x] == Y[x]}, {Y[x], Z[x]}, {x}]"
					or result == "DSolve[{Y'[x] == Z[x], Z'[x] == Y[x]}, {Z[x], Y[x]}, {x}]"
			)
		end)
		it("renders attached initial conditions with mapped dependent variables", function()
			local ast = {
				type = "ode_system",
				equations = {
					{
						type = "ode",
						lhs = {
							type = "ordinary_derivative",
							expression = { type = "variable", name = "y" },
							variable = { type = "variable", name = "x" },
							order = { type = "number", value = 2 },
						},
						rhs = { type = "number", value = 0 },
					},
				},
				conditions = {
					{
						type = "binary",
						operator = "=",
						left = {
							type = "function_call",
							name_node = { type = "variable", name = "y" },
							args = { { type = "number", value = 0 } },
						},
						right = { type = "number", value = 1 },
					},
					{
						type = "binary",
						operator = "=",
						left = {
							type = "ordinary_derivative",
							expression = {
								type = "function_call",
								name_node = { type = "variable", name = "y" },
								args = { { type = "number", value = 0 } },
							},
							variable = { type = "variable", name = "x" },
							order = { type = "number", value = 1 },
						},
						right = { type = "number", value = 0 },
					},
				},
			}

			local result = handlers.ode_system(ast, mock_render)

			assert.is_truthy(result:match("Y%[%s*0%s*%]%s*==%s*1"))
			assert.is_truthy(result:match("Y'%[%s*0%s*%]%s*==%s*0"))
		end)

		it("rebinds derivative conditions using the mapped independent variable", function()
			local ast = {
				type = "ode_system",
				equations = {
					{
						type = "ode",
						lhs = {
							type = "ordinary_derivative",
							expression = { type = "variable", name = "y" },
							variable = { type = "variable", name = "x" },
							order = { type = "number", value = 2 },
						},
						rhs = { type = "number", value = 0 },
					},
				},
				conditions = {
					{
						type = "binary",
						operator = "=",
						left = {
							type = "ordinary_derivative",
							expression = {
								type = "function_call",
								name_node = { type = "variable", name = "y" },
								args = { { type = "number", value = 0 } },
							},
							variable = { type = "number", value = 0 },
							order = { type = "number", value = 1 },
						},
						right = { type = "number", value = 0 },
					},
				},
			}

			local result = handlers.ode_system(ast, mock_render)

			local prime_render = handlers.ordinary_derivative({
				type = "ordinary_derivative",
				expression = {
					type = "function_call",
					name_node = { type = "variable", name = "y" },
					args = { { type = "variable", name = "x" } },
				},
				variable = { type = "variable", name = "x" },
				order = { type = "number", value = 1 },
			}, mock_render)
			assert.is_truthy(result:match("Y'%[%s*0%s*%]%s*==%s*0"))
			assert.is_falsy(result:match("D%[Y%[0%]"))
			assert.are.equal("D[Y[x], x]", prime_render)
		end)
	end)

	describe("wronskian handler", function()
		it("should correctly format the Wronskian function", function()
			local ast = {
				type = "wronskian",
				functions = {
					{ type = "variable", name = "f" },
					{ type = "variable", name = "g" },
				},
			}
			local result = handlers.wronskian(ast, mock_render)
			assert.are.same("Wronskian[{f[x], g[x]}, x]", result)
		end)

		it("should treat subscripted functions as dependent on the variable", function()
			local ast = {
				type = "wronskian",
				functions = {
					{
						type = "subscript",
						base = { type = "variable", name = "y" },
						subscript = { type = "number", value = 1 },
					},
					{
						type = "subscript",
						base = { type = "variable", name = "y" },
						subscript = { type = "number", value = 2 },
					},
				},
			}

			local result = handlers.wronskian(ast, mock_render)
			assert.are.same("Wronskian[{Subscript[y, 1][x], Subscript[y, 2][x]}, x]", result)
		end)
	end)

	describe("laplace_transform handler", function()
		it("should correctly format the LaplaceTransform function", function()
			local ast = {
				type = "laplace_transform",
				expression = {
					type = "function_call",
					name_node = { type = "variable", name = "f" },
					args = { { type = "variable", name = "t" } },
				},
			}
			local result = handlers.laplace_transform(ast, mock_render)
			assert.are.same("LaplaceTransform[F[t], t, s]", result)
		end)
	end)

	describe("inverse_laplace_transform handler", function()
		it("should correctly format the InverseLaplaceTransform function", function()
			local ast = {
				type = "inverse_laplace_transform",
				expression = {
					type = "function_call",
					name_node = { type = "variable", name = "F" },
					args = { { type = "variable", name = "s" } },
				},
			}
			local result = handlers.inverse_laplace_transform(ast, mock_render)
			assert.are.same("InverseLaplaceTransform[F[s], s, t]", result)
		end)
	end)

	describe("convolution handler", function()
		it("should correctly format the Convolve function", function()
			local ast = {
				type = "convolution",
				left = { type = "variable", name = "f" },
				right = { type = "variable", name = "g" },
			}
			local result = handlers.convolution(ast, mock_render)
			assert.are.same("Convolve[f, g, t, y]", result)
		end)
	end)
end)
