-- tests/unit/domains/differential_equations/rules/ode_spec.lua
-- Busted tests for the ODE parsing rule.

local lpeg = require("lpeglabel")
local P, V, C, R, S, Ct, Cg, Cf = lpeg.P, lpeg.V, lpeg.C, lpeg.R, lpeg.S, lpeg.Ct, lpeg.Cg, lpeg.Cf

describe("Differential Equations ODE Rule", function()
	local test_grammar
	local function parse_input(input_str)
		assert(test_grammar, "Test grammar was not compiled for test")
		return lpeg.match(test_grammar, input_str)
	end

	before_each(function()
		local mock_space = S(" \t\n\r") ^ 0
		local mock_tk = {
			space = mock_space,
			lbrace = P("{"),
			rbrace = P("}"),
			equals_op = P("&=") + (P("&") * mock_space * P("=")) + P("="),
			variable = C(R("az", "AZ") ^ 1) / function(s)
				return { type = "variable", name = s }
			end,
			number = C(R("09") ^ 1) / function(s)
				return { type = "number", value = tonumber(s) }
			end,
		}
		package.loaded["tungsten.core.tokenizer"] = mock_tk
		package.loaded["tungsten.core.ast"] = {
			create_binary_operation_node = function(op, left, right)
				return { type = "binary", operator = op, left = left, right = right }
			end,
			create_ode_node = function(lhs, rhs)
				return { type = "ode", lhs = lhs, rhs = rhs }
			end,
		}

		local g = {}
		g.Atom = mock_tk.variable + mock_tk.number

		g.LagrangeNotation = (V("Atom") * C(P("'") ^ 1))
			/ function(atom, primes)
				return { type = "derivative", notation = "lagrange", variable = atom, order = #primes }
			end

		g.NewtonDot = P("\\ddot") / function()
			return 2
		end + P("\\dot") / function()
			return 1
		end
		local braced_atom = mock_tk.space * P("{") * mock_tk.space * V("Atom") * mock_tk.space * P("}")
		local plain_atom = V("Atom")
		g.NewtonNotation = (V("NewtonDot") * (braced_atom + plain_atom))
			/ function(order, atom)
				return { type = "derivative", notation = "newton", variable = atom, order = order }
			end

		g.LeibnizNotation = (
			P("\\frac")
			* mock_tk.space
			* P("{")
			* mock_tk.space
			* P("d")
			* V("Atom")
			* mock_tk.space
			* P("}")
			* mock_tk.space
			* P("{")
			* mock_tk.space
			* P("d")
			* V("Atom")
			* mock_tk.space
			* P("}")
		)
			/ function(dep, indep)
				return {
					type = "derivative",
					notation = "leibniz",
					dependent_variable = dep,
					independent_variable = indep,
					order = 1,
				}
			end

		g.Derivative = V("LagrangeNotation") + V("NewtonNotation") + V("LeibnizNotation")
		g.Term = V("Derivative") + V("Atom")

		g.Expression = Cf(V("Term") * (mock_tk.space * Ct(C(S("+-")) * mock_tk.space * V("Term"))) ^ 0, function(acc, pair)
			return package.loaded["tungsten.core.ast"].create_binary_operation_node(pair[1], acc, pair[2])
		end)

		g.MainODERule = Ct(
			Cg(V("Expression"), "lhs") * mock_tk.space * mock_tk.equals_op * mock_tk.space * Cg(V("Expression"), "rhs")
		) / function(captures)
			return package.loaded["tungsten.core.ast"].create_ode_node(captures.lhs, captures.rhs)
		end

		g.ODE = V("MainODERule")

		g[1] = V("ODE")
		test_grammar = P(g)
	end)

	describe("Lagrange Notation", function()
		it("should parse y' = y", function()
			local result = parse_input("y' = y")
			assert.is_table(result)
			assert.are.same({
				type = "derivative",
				notation = "lagrange",
				order = 1,
				variable = { type = "variable", name = "y" },
			}, result.lhs)
		end)

		it("should parse y'' + y' = 0", function()
			local result = parse_input("y'' + y' = 0")
			assert.is_table(result)
			assert.are.same({
				type = "binary",
				operator = "+",
				left = { type = "derivative", notation = "lagrange", order = 2, variable = { type = "variable", name = "y" } },
				right = { type = "derivative", notation = "lagrange", order = 1, variable = { type = "variable", name = "y" } },
			}, result.lhs)
		end)

		it("should parse y'' + y' &= 0 using aligned equals", function()
			local result = parse_input("y'' + y' &= 0")
			assert.is_table(result)
			assert.are.same({
				type = "binary",
				operator = "+",
				left = { type = "derivative", notation = "lagrange", order = 2, variable = { type = "variable", name = "y" } },
				right = { type = "derivative", notation = "lagrange", order = 1, variable = { type = "variable", name = "y" } },
			}, result.lhs)
		end)
	end)

	describe("Leibniz Notation", function()
		it("should parse \\frac{dy}{dx} = y", function()
			local result = parse_input("\\frac{dy}{dx} = y")
			assert.is_table(result)
			assert.are.same({
				type = "derivative",
				notation = "leibniz",
				order = 1,
				dependent_variable = { type = "variable", name = "y" },
				independent_variable = { type = "variable", name = "x" },
			}, result.lhs)
		end)
	end)

	describe("Newton Notation", function()
		it("should parse \\dot{x} = x", function()
			local result = parse_input("\\dot{x} = x")
			assert.is_table(result)
			assert.are.same({
				type = "derivative",
				notation = "newton",
				order = 1,
				variable = { type = "variable", name = "x" },
			}, result.lhs)
		end)

		it("should parse \\ddot{x} + \\dot{x} = 0", function()
			local result = parse_input("\\ddot{x} + \\dot{x} = 0")
			assert.is_table(result)
			assert.are.same({
				type = "binary",
				operator = "+",
				left = { type = "derivative", notation = "newton", order = 2, variable = { type = "variable", name = "x" } },
				right = { type = "derivative", notation = "newton", order = 1, variable = { type = "variable", name = "x" } },
			}, result.lhs)
		end)

		it("should parse with braces \\dot{x} = x", function()
			local result = parse_input("\\dot{x} = x")
			assert.is_table(result)
			assert.are.same({
				type = "derivative",
				notation = "newton",
				order = 1,
				variable = { type = "variable", name = "x" },
			}, result.lhs)
		end)
	end)

	describe("Complex Equations", function()
		it("should parse derivatives on both sides: y' = y''", function()
			local result = parse_input("y' = y''")
			assert.is_table(result)
			assert.are.same({
				type = "derivative",
				notation = "lagrange",
				order = 1,
				variable = { type = "variable", name = "y" },
			}, result.lhs)
			assert.are.same({
				type = "derivative",
				notation = "lagrange",
				order = 2,
				variable = { type = "variable", name = "y" },
			}, result.rhs)
		end)

		it("should parse a mix of notations: \\ddot{x} = \\frac{dy}{dt}", function()
			local result = parse_input("\\ddot{x} = \\frac{dy}{dt}")
			assert.is_table(result)
			assert.are.same({
				type = "derivative",
				notation = "newton",
				order = 2,
				variable = { type = "variable", name = "x" },
			}, result.lhs)
			assert.are.same({
				type = "derivative",
				notation = "leibniz",
				order = 1,
				dependent_variable = { type = "variable", name = "y" },
				independent_variable = { type = "variable", name = "t" },
			}, result.rhs)
		end)
	end)
end)
