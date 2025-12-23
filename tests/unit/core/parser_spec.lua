-- tests/unit/core/parser_spec.lua
-- Unit tests for the LPeg parser functionality in core/parser.lua
---------------------------------------------------------------------

package.loaded["tungsten.core.registry"] = nil
package.loaded["tungsten.core.parser"] = nil
package.loaded["tungsten.core"] = nil
package.loaded["tungsten.domains.arithmetic"] = nil
package.loaded["tungsten.domains.calculus"] = nil
package.loaded["tungsten.domains.linear_algebra"] = nil
package.loaded["tungsten.domains.differential_equations"] = nil

local parser = require("tungsten.core.parser")
require("tungsten.core")
local ast_utils = require("tungsten.core.ast")

describe("tungsten.core.parser.parse with combined grammar", function()
	local function parse_input(input_str)
		local res = parser.parse(input_str)
		if res and res.series and res.series[1] then
			return res.series[1]
		end
		return nil
	end

	describe("basic arithmetic operations", function()
		it("should parse addition: 1 + 2", function()
			local input = "1 + 2"
			local expected_ast = ast_utils.create_binary_operation_node(
				"+",
				{ type = "number", value = 1 },
				{ type = "number", value = 2 }
			)
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse subtraction: 2 - 1", function()
			local input = "2 - 1"
			local expected_ast = ast_utils.create_binary_operation_node(
				"-",
				{ type = "number", value = 2 },
				{ type = "number", value = 1 }
			)
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse multiplication with *: 3 * 4 (verifying * operator)", function()
			local input = "3 * 4"
			local expected_ast = ast_utils.create_binary_operation_node(
				"*",
				{ type = "number", value = 3 },
				{ type = "number", value = 4 }
			)
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse multiplication with \\cdot: 3 \\cdot 4", function()
			local input = "3 \\cdot 4"
			local expected_ast = ast_utils.create_binary_operation_node(
				"*",
				{ type = "number", value = 3 },
				{ type = "number", value = 4 }
			)
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse division: 5 / 6", function()
			local input = "5 / 6"
			local expected_ast = ast_utils.create_binary_operation_node(
				"/",
				{ type = "number", value = 5 },
				{ type = "number", value = 6 }
			)
			assert.are.same(expected_ast, parse_input(input))
		end)
	end)

	describe("order of operations", function()
		it("should parse 1 + 2 \\cdot 3 correctly (multiplication before addition)", function()
			local input = "1 + 2 \\cdot 3"
			local expected_ast = ast_utils.create_binary_operation_node(
				"+",
				{ type = "number", value = 1 },
				ast_utils.create_binary_operation_node("*", { type = "number", value = 2 }, { type = "number", value = 3 })
			)
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse 1 \\cdot 2 + 3 correctly (multiplication before addition)", function()
			local input = "1 \\cdot 2 + 3"
			local expected_ast = ast_utils.create_binary_operation_node(
				"+",
				ast_utils.create_binary_operation_node("*", { type = "number", value = 1 }, { type = "number", value = 2 }),
				{ type = "number", value = 3 }
			)
			assert.are.same(expected_ast, parse_input(input))
		end)
	end)

	describe("parenthesized expressions", function()
		it("should parse (1 + 2) \\cdot 3 correctly", function()
			local input = "(1 + 2) \\cdot 3"
			local expected_ast = ast_utils.create_binary_operation_node(
				"*",
				ast_utils.create_binary_operation_node("+", { type = "number", value = 1 }, { type = "number", value = 2 }),
				{ type = "number", value = 3 }
			)
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse 1 \\cdot (2 + 3) correctly", function()
			local input = "1 \\cdot (2 + 3)"
			local expected_ast = ast_utils.create_binary_operation_node(
				"*",
				{ type = "number", value = 1 },
				ast_utils.create_binary_operation_node("+", { type = "number", value = 2 }, { type = "number", value = 3 })
			)
			assert.are.same(expected_ast, parse_input(input))
		end)
	end)

	describe("fractions", function()
		it("should parse \\frac{a}{b}", function()
			local input = "\\frac{a}{b}"
			local expected_ast = ast_utils.create_fraction_node(
				{ type = "variable", name = "a" },
				{ type = "variable", name = "b" }
			)
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse \\frac{1+x}{y-2}", function()
			local input = "\\frac{1+x}{y-2}"
			local expected_ast = ast_utils.create_fraction_node(
				ast_utils.create_binary_operation_node("+", { type = "number", value = 1 }, { type = "variable", name = "x" }),
				ast_utils.create_binary_operation_node("-", { type = "variable", name = "y" }, { type = "number", value = 2 })
			)
			assert.are.same(expected_ast, parse_input(input))
		end)
	end)

	describe("square roots", function()
		it("should parse \\sqrt{x}", function()
			local input = "\\sqrt{x}"
			local expected_ast = ast_utils.create_sqrt_node({ type = "variable", name = "x" }, nil)
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse \\sqrt[3]{y}", function()
			local input = "\\sqrt[3]{y}"
			local expected_ast = ast_utils.create_sqrt_node({ type = "variable", name = "y" }, { type = "number", value = 3 })
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse \\sqrt{x^2+y^2}", function()
			local input = "\\sqrt{x^2+y^2}"
			local expected_ast = ast_utils.create_sqrt_node(
				ast_utils.create_binary_operation_node(
					"+",
					ast_utils.create_superscript_node({ type = "variable", name = "x" }, { type = "number", value = 2 }),
					ast_utils.create_superscript_node({ type = "variable", name = "y" }, { type = "number", value = 2 })
				),
				nil
			)
			assert.are.same(expected_ast, parse_input(input))
		end)
	end)

	describe("superscripts and subscripts", function()
		it("should parse x^2", function()
			local input = "x^2"
			local expected_ast = ast_utils.create_superscript_node(
				{ type = "variable", name = "x" },
				{ type = "number", value = 2 }
			)
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse y_i", function()
			local input = "y_i"
			local expected_ast = ast_utils.create_subscript_node(
				{ type = "variable", name = "y" },
				{ type = "variable", name = "i" }
			)
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse z_i^2 (subscript then superscript)", function()
			local input = "z_i^2"
			local expected_ast = ast_utils.create_superscript_node(
				ast_utils.create_subscript_node({ type = "variable", name = "z" }, { type = "variable", name = "i" }),
				{ type = "number", value = 2 }
			)
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse x^{a+b}", function()
			local input = "x^{a+b}"
			local expected_ast = ast_utils.create_superscript_node(
				{ type = "variable", name = "x" },
				ast_utils.create_binary_operation_node(
					"+",
					{ type = "variable", name = "a" },
					{ type = "variable", name = "b" }
				)
			)
			assert.are.same(expected_ast, parse_input(input))
		end)
	end)

	describe("unary operators", function()
		it("should parse -5", function()
			local input = "-5"
			local expected_ast = ast_utils.create_unary_operation_node("-", { type = "number", value = 5 })
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse +x", function()
			local input = "+x"
			local expected_ast = ast_utils.create_unary_operation_node("+", { type = "variable", name = "x" })
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse -(1+2)", function()
			local input = "-(1+2)"
			local expected_ast = ast_utils.create_unary_operation_node(
				"-",
				ast_utils.create_binary_operation_node("+", { type = "number", value = 1 }, { type = "number", value = 2 })
			)
			assert.are.same(expected_ast, parse_input(input))
		end)
	end)

	describe("variables and Greek letters", function()
		it("should parse a single variable x", function()
			local input = "x"
			local expected_ast = { type = "variable", name = "x" }
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse a multi-character variable 'alphaPrime'", function()
			local input = "alphaPrime"
			local expected_ast = { type = "variable", name = "alphaPrime" }
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse \\alpha", function()
			local input = "\\alpha"
			local expected_ast = { type = "greek", name = "alpha" }
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse \\beta + \\gamma", function()
			local input = "\\beta + \\gamma"
			local expected_ast = ast_utils.create_binary_operation_node(
				"+",
				{ type = "greek", name = "beta" },
				{ type = "greek", name = "gamma" }
			)
			assert.are.same(expected_ast, parse_input(input))
		end)
	end)

	describe("implicit multiplication", function()
		it("should parse 2x as 2 \\cdot x (implicitly)", function()
			local input = "2x"
			local expected_ast = ast_utils.create_binary_operation_node(
				"*",
				{ type = "number", value = 2 },
				{ type = "variable", name = "x" }
			)
			assert.are.same(expected_ast, parse_input(input))
		end)
		it("should parse x y as x \\cdot y (implicitly)", function()
			local input = "x y"
			local expected_ast = ast_utils.create_binary_operation_node(
				"*",
				{ type = "variable", name = "x" },
				{ type = "variable", name = "y" }
			)
			assert.are.same(expected_ast, parse_input(input))
		end)
		it("should parse (1+2)x as (1+2) \\cdot x (implicitly)", function()
			local input = "(1+2)x"
			local expected_ast = ast_utils.create_binary_operation_node(
				"*",
				ast_utils.create_binary_operation_node("+", { type = "number", value = 1 }, { type = "number", value = 2 }),
				{ type = "variable", name = "x" }
			)
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse 2\\alpha as 2 \\cdot \\alpha (implicitly)", function()
			local input = "2\\alpha"
			local expected_ast = ast_utils.create_binary_operation_node(
				"*",
				{ type = "number", value = 2 },
				{ type = "greek", name = "alpha" }
			)
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse \\sin(x) \\cos(y) as implicit multiplication", function()
			local input = "\\sin(x) \\cos(y)"
			local expected_ast = ast_utils.create_binary_operation_node(
				"*",
				ast_utils.create_function_call_node({ type = "variable", name = "sin" }, {
					{ type = "variable", name = "x" },
				}),
				ast_utils.create_function_call_node({ type = "variable", name = "cos" }, {
					{ type = "variable", name = "y" },
				})
			)

			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse \\ln x as a natural log function call", function()
			local input = "\\ln x"
			local expected_ast = ast_utils.create_function_call_node({ type = "variable", name = "ln" }, {
				{ type = "variable", name = "x" },
			})

			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse \\ln(x) as a natural log function call", function()
			local input = "\\ln(x)"
			local expected_ast = ast_utils.create_function_call_node({ type = "variable", name = "ln" }, {
				{ type = "variable", name = "x" },
			})

			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse \\log x as a logarithm function call", function()
			local input = "\\log x"
			local expected_ast = ast_utils.create_function_call_node({ type = "variable", name = "log" }, {
				{ type = "variable", name = "x" },
			})

			assert.are.same(expected_ast, parse_input(input))
		end)
	end)

	describe("relations", function()
		it("should parse y = f(x) as an Equality node", function()
			local input = "y = f(x)"
			local expected_ast = ast_utils.create_equality_node(
				{ type = "variable", name = "y" },
				ast_utils.create_function_call_node({ type = "variable", name = "f" }, { { type = "variable", name = "x" } })
			)
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse x^2 + y^2 = 1", function()
			local input = "x^2 + y^2 = 1"
			local lhs = ast_utils.create_binary_operation_node(
				"+",
				ast_utils.create_superscript_node({ type = "variable", name = "x" }, { type = "number", value = 2 }),
				ast_utils.create_superscript_node({ type = "variable", name = "y" }, { type = "number", value = 2 })
			)
			local expected_ast = ast_utils.create_equality_node(lhs, { type = "number", value = 1 })
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse inequalities including LaTeX variants", function()
			local result = parse_input("x \\ge 0")
			assert.are.same(
				ast_utils.create_inequality_node({ type = "variable", name = "x" }, "≥", { type = "number", value = 0 }),
				result
			)

			result = parse_input("x \\leq y")
			assert.are.same(
				ast_utils.create_inequality_node({ type = "variable", name = "x" }, "≤", { type = "variable", name = "y" }),
				result
			)
		end)
	end)

	describe("linear algebra operations", function()
		describe("matrix parsing", function()
			it("should parse a simple 2x2 pmatrix: \\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}", function()
				local input = "\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}"
				local expected_ast = ast_utils.create_matrix_node({
					{ { type = "variable", name = "a" }, { type = "variable", name = "b" } },
					{ { type = "variable", name = "c" }, { type = "variable", name = "d" } },
				})
				local parsed = parse_input(input)
				assert.are.equal("matrix", parsed.type)
				assert.are.same(expected_ast.rows, parsed.rows)
			end)

			it("should parse a 1x3 bmatrix: \\begin{bmatrix} 1 & 2 & 3 \\end{bmatrix}", function()
				local input = "\\begin{bmatrix} 1 & 2 & 3 \\end{bmatrix}"
				local expected_ast = ast_utils.create_matrix_node({
					{ { type = "number", value = 1 }, { type = "number", value = 2 }, { type = "number", value = 3 } },
				})
				local parsed = parse_input(input)
				assert.are.equal("matrix", parsed.type)
				assert.are.same(expected_ast.rows, parsed.rows)
			end)

			it(
				"should parse a 3x1 vmatrix with complex entries as a determinant: \\begin{vmatrix} x^2 \\\\ \\frac{1}{y} \\\\ z_i \\end{vmatrix}",
				function()
					local input = "\\begin{vmatrix} x^2 \\\\ \\frac{1}{y} \\\\ z_i \\end{vmatrix}"
					local matrix_ast = ast_utils.create_matrix_node({
						{ ast_utils.create_superscript_node({ type = "variable", name = "x" }, { type = "number", value = 2 }) },
						{ ast_utils.create_fraction_node({ type = "number", value = 1 }, { type = "variable", name = "y" }) },
						{ ast_utils.create_subscript_node({ type = "variable", name = "z" }, { type = "variable", name = "i" }) },
					})
					local expected_ast = ast_utils.create_determinant_node(matrix_ast)
					local parsed = parse_input(input)
					assert.are.equal("determinant", parsed.type)
					assert.are.equal("matrix", parsed.expression.type)
					assert.are.same(expected_ast.expression.rows, parsed.expression.rows)
				end
			)

			it("should not parse matrix with no elements: \\begin{pmatrix} \\end{pmatrix}", function()
				local input = "\\begin{pmatrix} \\end{pmatrix}"
				assert.is_nil(parse_input(input))
			end)
		end)

		describe("symbolic vector parsing", function()
			it("should parse \\vec{a}", function()
				local input = "\\vec{a}"
				local expected_ast = ast_utils.create_symbolic_vector_node({ type = "variable", name = "a" }, "vec")
				assert.are.same(expected_ast, parse_input(input))
			end)

			it("should parse \\mathbf{x_i}", function()
				local input = "\\mathbf{x_i}"
				local expected_ast = ast_utils.create_symbolic_vector_node(
					ast_utils.create_subscript_node({ type = "variable", name = "x" }, { type = "variable", name = "i" }),
					"mathbf"
				)
				assert.are.same(expected_ast, parse_input(input))
			end)

			it("should not parse \\vec a (no braces)", function()
				local input = "\\vec a"
				assert.is_nil(parse_input(input))
			end)
		end)

		describe("determinant parsing", function()
			it("should parse \\det(A)", function()
				local input = "\\det(A)"
				local expected_ast = ast_utils.create_determinant_node({ type = "variable", name = "A" })
				assert.are.same(expected_ast, parse_input(input))
			end)

			it("should parse |M|", function()
				local input = "|M|"
				local expected_ast = ast_utils.create_determinant_node({ type = "variable", name = "M" })
				assert.are.same(expected_ast, parse_input(input))
			end)

			it("should parse \\det(\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix})", function()
				local input = "\\det(\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix})"
				local matrix_ast = ast_utils.create_matrix_node({
					{ { type = "variable", name = "a" }, { type = "variable", name = "b" } },
					{ { type = "variable", name = "c" }, { type = "variable", name = "d" } },
				})
				local expected_ast = ast_utils.create_determinant_node(matrix_ast)
				local parsed = parse_input(input)
				assert.are.equal("determinant", parsed.type)
				assert.are.equal("matrix", parsed.expression.type)
				assert.are.same(expected_ast.expression.rows, parsed.expression.rows)
			end)

			it("should parse |\\begin{bmatrix} 1 & 0 \\\\ 0 & 1 \\end{bmatrix}|", function()
				local input = "|\\begin{bmatrix} 1 & 0 \\\\ 0 & 1 \\end{bmatrix}|"
				local matrix_ast = ast_utils.create_matrix_node({
					{ { type = "number", value = 1 }, { type = "number", value = 0 } },
					{ { type = "number", value = 0 }, { type = "number", value = 1 } },
				})
				local expected_ast = ast_utils.create_norm_node(matrix_ast)
				local parsed = parse_input(input)
				assert.are.equal("norm", parsed.type)
				assert.are.equal("matrix", parsed.expression.type)
				assert.are.same(expected_ast.expression.rows, parsed.expression.rows)
			end)

			it("should not parse \\det A (no parentheses)", function()
				local input = "\\det A"
				assert.is_nil(parse_input(input))
			end)

			it("should not parse |A (unmatched bar)", function()
				local input = "|A"
				assert.is_nil(parse_input(input))
			end)
		end)

		describe("transpose parsing", function()
			it("should parse \\vec{A}^T as superscript", function()
				local input = "\\vec{A}^T"
				local expected_ast = ast_utils.create_superscript_node(
					ast_utils.create_symbolic_vector_node({ type = "variable", name = "A" }, "vec"),
					{ type = "variable", name = "T" }
				)
				assert.are.same(expected_ast, parse_input(input))
			end)

			it("should parse \\vec{M}^{\\intercal} as superscript", function()
				local input = "\\vec{M}^{\\intercal}"
				local expected_ast = ast_utils.create_superscript_node(
					ast_utils.create_symbolic_vector_node({ type = "variable", name = "M" }, "vec"),
					{ type = "intercal_command" }
				)
				assert.are.same(expected_ast, parse_input(input))
			end)

			it("should parse \\vec{(X_i)}^T as superscript", function()
				local input = "\\vec{(X_i)}^T"
				local expected_ast = ast_utils.create_superscript_node(
					ast_utils.create_symbolic_vector_node(
						ast_utils.create_subscript_node({ type = "variable", name = "X" }, { type = "variable", name = "i" }),
						"vec"
					),
					{ type = "variable", name = "T" }
				)
				assert.are.same(expected_ast, parse_input(input))
			end)

			it("should not parse A^t (lowercase 't')", function()
				local input = "A^t"
				local parsed = parse_input(input)
				if parsed and parsed.type == "transpose" then
					assert.fail("Parsed A^t as transpose, but it should be a superscript or nil.")
				end
				local expected_ast = ast_utils.create_superscript_node(
					{ type = "variable", name = "A" },
					{ type = "variable", name = "t" }
				)
				assert.are.same(expected_ast, parsed)
			end)
		end)

		describe("inverse parsing", function()
			it("should parse \\vec{A}^{-1} as superscript", function()
				local input = "\\vec{A}^{-1}"
				local expected_ast = ast_utils.create_superscript_node(
					ast_utils.create_symbolic_vector_node({ type = "variable", name = "A" }, "vec"),
					{ type = "unary", operator = "-", value = { type = "number", value = 1 } }
				)
				assert.are.same(expected_ast, parse_input(input))
			end)

			it("should parse \\vec{(M_1)}^{-1} as superscript", function()
				local input = "\\vec{(M_1)}^{-1}"
				local expected_ast = ast_utils.create_superscript_node(
					ast_utils.create_symbolic_vector_node(
						ast_utils.create_subscript_node({ type = "variable", name = "M" }, { type = "number", value = 1 }),
						"vec"
					),
					{ type = "unary", operator = "-", value = { type = "number", value = 1 } }
				)
				assert.are.same(expected_ast, parse_input(input))
			end)

			it("should not parse A^-1 (no braces)", function()
				local input = "A^-1"
				assert.is_nil(parse_input(input))
			end)

			it("should not parse A^{1} (wrong exponent)", function()
				local input = "A^{1}"
				local parsed = parse_input(input)
				if parsed then
					assert.are_not.equal("inverse", parsed.type)
				else
					assert.is_nil(parsed)
				end
			end)
		end)

		describe("dot product parsing", function()
			it("should parse \\vec{a} \\cdot \\vec{b}", function()
				local input = "\\vec{a} \\cdot \\vec{b}"
				local expected_ast = ast_utils.create_dot_product_node(
					ast_utils.create_symbolic_vector_node({ type = "variable", name = "a" }, "vec"),
					ast_utils.create_symbolic_vector_node({ type = "variable", name = "b" }, "vec")
				)
				assert.are.same(expected_ast, parse_input(input))
			end)

			it("should parse x \\cdot y (simple variables as multiplication)", function()
				local input = "x \\cdot y"
				local expected_ast = ast_utils.create_binary_operation_node(
					"*",
					{ type = "variable", name = "x" },
					{ type = "variable", name = "y" }
				)
				assert.are.same(expected_ast, parse_input(input))
			end)

			it("should not parse a \\times b (wrong operator, becomes multiplication)", function()
				local input = "a \\times b"
				local expected_ast = ast_utils.create_binary_operation_node(
					"*",
					{ type = "variable", name = "a" },
					{ type = "variable", name = "b" }
				)
				assert.are.same(expected_ast, parse_input(input))
			end)
		end)

		describe("cross product parsing", function()
			it("should parse \\vec{u} \\times \\vec{v}", function()
				local input = "\\vec{u} \\times \\vec{v}"
				local expected_ast = ast_utils.create_cross_product_node(
					ast_utils.create_symbolic_vector_node({ type = "variable", name = "u" }, "vec"),
					ast_utils.create_symbolic_vector_node({ type = "variable", name = "v" }, "vec")
				)
				assert.are.same(expected_ast, parse_input(input))
			end)

			it("should parse p \\times q (simple variables as multiplication)", function()
				local input = "p \\times q"
				local expected_ast = ast_utils.create_binary_operation_node(
					"*",
					{ type = "variable", name = "p" },
					{ type = "variable", name = "q" }
				)
				assert.are.same(expected_ast, parse_input(input))
			end)

			it("should not parse u \\cdot v (wrong operator, becomes multiplication)", function()
				local input = "u \\cdot v"
				local expected_ast = ast_utils.create_binary_operation_node(
					"*",
					{ type = "variable", name = "u" },
					{ type = "variable", name = "v" }
				)
				local parsed = parse_input(input)
				assert.are.same(expected_ast, parsed)
				if parsed then
					assert.are_not.equal("cross_product", parsed.type)
				end
			end)
		end)

		describe("norm parsing", function()
			it("should parse ||x||", function()
				local input = "||x||"
				local expected_ast = ast_utils.create_norm_node({ type = "variable", name = "x" }, nil)
				assert.are.same(expected_ast, parse_input(input))
			end)

			it("should parse \\| \\vec{v} \\|_2", function()
				local input = "\\| \\vec{v} \\|_2"
				local expected_ast = ast_utils.create_norm_node(
					ast_utils.create_symbolic_vector_node({ type = "variable", name = "v" }, "vec"),
					{ type = "number", value = 2 }
				)
				assert.are.same(expected_ast, parse_input(input))
			end)

			it("should parse ||A||_F (Frobenius norm)", function()
				local input = "||A||_F"
				local expected_ast = ast_utils.create_norm_node(
					{ type = "variable", name = "A" },
					{ type = "variable", name = "F" }
				)
				assert.are.same(expected_ast, parse_input(input))
			end)

			it("should parse |\\begin{bmatrix} 1 & 2 & 3 \\end{bmatrix}| as a norm", function()
				local input = "|\\begin{bmatrix} 1 & 2 & 3 \\end{bmatrix}|"
				local matrix_ast = ast_utils.create_matrix_node({
					{ { type = "number", value = 1 }, { type = "number", value = 2 }, { type = "number", value = 3 } },
				}, "bmatrix")
				local expected_ast = ast_utils.create_norm_node(matrix_ast, nil)
				assert.are.same(expected_ast, parse_input(input))
			end)

			it("should parse \\|\\begin{bmatrix} 1 & 2 & 3 \\end{bmatrix}\\|", function()
				local input = "\\|\\begin{bmatrix} 1 & 2 & 3 \\end{bmatrix}\\|"
				local matrix_ast = ast_utils.create_matrix_node({
					{ { type = "number", value = 1 }, { type = "number", value = 2 }, { type = "number", value = 3 } },
				}, "bmatrix")
				local expected_ast = ast_utils.create_norm_node(matrix_ast, nil)
				assert.are.same(expected_ast, parse_input(input))
			end)

			it("should parse \\left| \\begin{bmatrix} 1 & 2 & 3 \\end{bmatrix} \\right| as a norm", function()
				local input = "\\left| \\begin{bmatrix} 1 & 2 & 3 \\end{bmatrix} \\right|"
				local matrix_ast = ast_utils.create_matrix_node({
					{ { type = "number", value = 1 }, { type = "number", value = 2 }, { type = "number", value = 3 } },
				}, "bmatrix")
				local expected_ast = ast_utils.create_norm_node(matrix_ast, nil)
				assert.are.same(expected_ast, parse_input(input))
			end)

			it("should parse \\| M \\|_{inf}", function()
				local input = "\\| M \\|_{inf}"
				local expected_ast = ast_utils.create_norm_node(
					{ type = "variable", name = "M" },
					{ type = "variable", name = "inf" }
				)
				assert.are.same(expected_ast, parse_input(input))
			end)

			it("should not parse |x| (single bars, should be abs/det)", function()
				local input = "|x|"
				local expected_ast = ast_utils.create_determinant_node({ type = "variable", name = "x" })
				assert.are.same(expected_ast, parse_input(input))
			end)

			it("should not parse ||x (unmatched norm)", function()
				local input = "||x"
				assert.is_nil(parse_input(input))
			end)
		end)

		describe("combined linear algebra operations", function()
			it("should parse \\det(A^T)", function()
				local input = "\\det(A^T)"
				local expected_ast = ast_utils.create_determinant_node(
					ast_utils.create_superscript_node({ type = "variable", name = "A" }, { type = "variable", name = "T" })
				)
				assert.are.same(expected_ast, parse_input(input))
			end)

			it("should parse ||\\vec{a} \\times \\vec{b}||", function()
				local input = "||\\vec{a} \\times \\vec{b}||"
				local expected_ast = ast_utils.create_norm_node(
					ast_utils.create_cross_product_node(
						ast_utils.create_symbolic_vector_node({ type = "variable", name = "a" }, "vec"),
						ast_utils.create_symbolic_vector_node({ type = "variable", name = "b" }, "vec")
					),
					nil
				)
				assert.are.same(expected_ast, parse_input(input))
			end)

			it("should parse (\\vec{u} \\cdot \\vec{v})^{-1}", function()
				local input = "(\\vec{u} \\cdot \\vec{v})^{-1}"
				local expected_ast = ast_utils.create_superscript_node(
					ast_utils.create_dot_product_node(
						ast_utils.create_symbolic_vector_node({ type = "variable", name = "u" }, "vec"),
						ast_utils.create_symbolic_vector_node({ type = "variable", name = "v" }, "vec")
					),
					ast_utils.create_unary_operation_node("-", { type = "number", value = 1 })
				)
				assert.are.same(expected_ast, parse_input(input))
			end)
		end)
	end)

	describe("calculus and arithmetic integration with linear algebra", function()
		it("should parse derivative of a determinant: \\frac{d}{dt} \\det(A(t))", function()
			local input = "\\frac{d}{dt} \\det(At)"
			local mock_At_var = { type = "variable", name = "At" }
			local expected_ast = ast_utils.create_ordinary_derivative_node(
				ast_utils.create_determinant_node(mock_At_var),
				{ type = "variable", name = "t" },
				{ type = "number", value = 1 }
			)
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse integral of a norm: \\int ||\\vec{x}(t)||_2 dt", function()
			local input = "\\int ||\\vec{xt}||_2 dt"
			local norm_expr = ast_utils.create_norm_node(
				ast_utils.create_symbolic_vector_node({ type = "variable", name = "xt" }, "vec"),
				{ type = "number", value = 2 }
			)
			local expected_ast = ast_utils.create_indefinite_integral_node(norm_expr, { type = "variable", name = "t" })
			assert.are.same(expected_ast, parse_input(input))
		end)
	end)

	describe("invalid syntax", function()
		it("should return nil for unmatched parenthesis: (1 + 2", function()
			local input = "(1 + 2"
			assert.is_nil(parse_input(input))
		end)

		it("should return nil for misplaced operator: 1 + \\cdot 2", function()
			local input = "1 + \\cdot 2"
			assert.is_nil(parse_input(input))
		end)

		it("should return nil for incomplete fraction: \\frac{1}", function()
			local input = "\\frac{1}"
			assert.is_nil(parse_input(input))
		end)

		it("should return nil for incomplete sqrt: \\sqrt[3]", function()
			local input = "\\sqrt[3]"
			assert.is_nil(parse_input(input))
		end)

		it("should return nil for bad superscript: x^", function()
			local input = "x^"
			assert.is_nil(parse_input(input))
		end)

		it("should return nil for just an operator: +", function()
			local input = "+"
			assert.is_nil(parse_input(input))
		end)
	end)

	describe("edge cases and complex structures", function()
		it("should parse nested fractions: \\frac{\\frac{a}{b}}{\\frac{c}{d}}", function()
			local input = "\\frac{\\frac{a}{b}}{\\frac{c}{d}}"
			local expected_ast = ast_utils.create_fraction_node(
				ast_utils.create_fraction_node({ type = "variable", name = "a" }, { type = "variable", name = "b" }),
				ast_utils.create_fraction_node({ type = "variable", name = "c" }, { type = "variable", name = "d" })
			)
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse expression with mixed brackets: [(1+2)\\cdot{3-4}]/5", function()
			local input = "[(1+2)\\cdot{3-4}]/5"
			local expected_ast = ast_utils.create_binary_operation_node(
				"/",
				ast_utils.create_binary_operation_node(
					"*",
					ast_utils.create_binary_operation_node("+", { type = "number", value = 1 }, { type = "number", value = 2 }),
					ast_utils.create_binary_operation_node("-", { type = "number", value = 3 }, { type = "number", value = 4 })
				),
				{ type = "number", value = 5 }
			)
			assert.are.same(expected_ast, parse_input(input))
		end)
	end)

	describe("calculus and arithmetic integration", function()
		it("should parse derivative of a fraction: \\frac{d}{dx} \\frac{x^2}{x+1}", function()
			local input = "\\frac{d}{dx} \\frac{x^2}{x+1}"
			local expected_ast = ast_utils.create_ordinary_derivative_node(
				ast_utils.create_fraction_node(
					ast_utils.create_superscript_node({ type = "variable", name = "x" }, { type = "number", value = 2 }),
					ast_utils.create_binary_operation_node("+", { type = "variable", name = "x" }, { type = "number", value = 1 })
				),
				{ type = "variable", name = "x" },
				{ type = "number", value = 1 }
			)
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should scope derivative to parentheses when present: \\frac{d}{dx} (x^3) + 2x", function()
			local input = "\\frac{d}{dx} (x^3) + 2x"
			local expected_ast = ast_utils.create_binary_operation_node(
				"+",
				ast_utils.create_ordinary_derivative_node(
					ast_utils.create_superscript_node({ type = "variable", name = "x" }, { type = "number", value = 3 }),
					{ type = "variable", name = "x" },
					{ type = "number", value = 1 }
				),
				ast_utils.create_binary_operation_node("*", { type = "number", value = 2 }, { type = "variable", name = "x" })
			)
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should use numerator expression when provided: \\frac{d x^3}{d x} + 3", function()
			local input = "\\frac{d x^3}{d x} + 3"
			local expected_ast = ast_utils.create_binary_operation_node(
				"+",
				ast_utils.create_ordinary_derivative_node(
					ast_utils.create_superscript_node({ type = "variable", name = "x" }, { type = "number", value = 3 }),
					{ type = "variable", name = "x" },
					{ type = "number", value = 1 }
				),
				{ type = "number", value = 3 }
			)
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse integral of an expression with variables and numbers: \\int x^2 + 2x dx", function()
			local input = "\\int x^2 + 2x dx"
			local expected_ast = ast_utils.create_indefinite_integral_node(
				ast_utils.create_binary_operation_node(
					"+",
					ast_utils.create_superscript_node({ type = "variable", name = "x" }, { type = "number", value = 2 }),
					ast_utils.create_binary_operation_node("*", { type = "number", value = 2 }, { type = "variable", name = "x" })
				),
				{ type = "variable", name = "x" }
			)
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should only differentiate parenthesized expressions after d/dx", function()
			local input = "\\frac{d}{dx} (x^3) + 2x"
			local derivative_ast = ast_utils.create_ordinary_derivative_node(
				ast_utils.create_superscript_node({ type = "variable", name = "x" }, { type = "number", value = 3 }),
				{ type = "variable", name = "x" },
				{ type = "number", value = 1 }
			)
			local expected_ast = ast_utils.create_binary_operation_node(
				"+",
				derivative_ast,
				ast_utils.create_binary_operation_node("*", { type = "number", value = 2 }, { type = "variable", name = "x" })
			)

			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should differentiate expressions included in the numerator of d/dx", function()
			local input = "\\frac{dx^3}{dx} + 3"
			local derivative_ast = ast_utils.create_ordinary_derivative_node(
				ast_utils.create_superscript_node({ type = "variable", name = "x" }, { type = "number", value = 3 }),
				{ type = "variable", name = "x" },
				{ type = "number", value = 1 }
			)

			local expected_ast = ast_utils.create_binary_operation_node("+", derivative_ast, { type = "number", value = 3 })

			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should only differentiate parenthesized expressions after partial derivatives", function()
			local input = "\\frac{\\partial}{\\partial x} (x^3) + 2y"
			local derivative_ast = ast_utils.create_partial_derivative_node(
				ast_utils.create_superscript_node({ type = "variable", name = "x" }, { type = "number", value = 3 }),
				{ type = "number", value = 1 },
				{
					ast_utils.create_differentiation_term_node({ type = "variable", name = "x" }, { type = "number", value = 1 }),
				}
			)

			local expected_ast = ast_utils.create_binary_operation_node(
				"+",
				derivative_ast,
				ast_utils.create_binary_operation_node("*", { type = "number", value = 2 }, { type = "variable", name = "y" })
			)

			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should differentiate expressions included in the numerator of partial derivatives", function()
			local input = "\\frac{\\partial x^3}{\\partial x} + 3"
			local derivative_ast = ast_utils.create_partial_derivative_node(
				ast_utils.create_superscript_node({ type = "variable", name = "x" }, { type = "number", value = 3 }),
				{ type = "number", value = 1 },
				{
					ast_utils.create_differentiation_term_node({ type = "variable", name = "x" }, { type = "number", value = 1 }),
				}
			)

			local expected_ast = ast_utils.create_binary_operation_node("+", derivative_ast, { type = "number", value = 3 })

			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse limit of a fraction: \\lim_{x \\to 0} \\frac{\\sin x}{x}", function()
			local input = "\\lim_{x \\to 0} \\frac{\\sin x}{x}"
			local parsed_ast = parse_input(input)
			assert.are.equal("limit", parsed_ast.type)
			assert.are.same({ type = "variable", name = "x" }, parsed_ast.variable)
			assert.are.same({ type = "number", value = 0 }, parsed_ast.point)
			assert.are.equal("fraction", parsed_ast.expression.type)
			if parsed_ast.expression.numerator.type == "function_call" then
				assert.are.same({ type = "variable", name = "sin" }, parsed_ast.expression.numerator.name_node)
				assert.are.same({ { type = "variable", name = "x" } }, parsed_ast.expression.numerator.args)
			else
				assert.fail("Numerator for \\sin x did not parse as function_call or implicit multiplication.")
			end
			assert.are.same({ type = "variable", name = "x" }, parsed_ast.expression.denominator)
		end)

		it("should parse sum with arithmetic in body: \\sum_{i=0}^{N} (i^2 + \\frac{1}{i})", function()
			local input = "\\sum_{i=0}^{N} (i^2 + \\frac{1}{i})"
			local expected_ast = ast_utils.create_summation_node(
				{ type = "variable", name = "i" },
				{ type = "number", value = 0 },
				{ type = "variable", name = "N" },
				ast_utils.create_binary_operation_node(
					"+",
					ast_utils.create_superscript_node({ type = "variable", name = "i" }, { type = "number", value = 2 }),
					ast_utils.create_fraction_node({ type = "number", value = 1 }, { type = "variable", name = "i" })
				)
			)
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse sum with arithmetic in body: \\sum_{i=0}^{N} (i^2 + \\frac{1}{i})", function()
			local input = "\\sum_{i=0}^{N} (i^2 + \\frac{1}{i})"
			local expected_ast = ast_utils.create_summation_node(
				{ type = "variable", name = "i" },
				{ type = "number", value = 0 },
				{ type = "variable", name = "N" },
				ast_utils.create_binary_operation_node(
					"+",
					ast_utils.create_superscript_node({ type = "variable", name = "i" }, { type = "number", value = 2 }),
					ast_utils.create_fraction_node({ type = "number", value = 1 }, { type = "variable", name = "i" })
				)
			)
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse summations with infinity as an upper bound", function()
			local input = "\\sum_{k=1}^{\\infty} 1"
			local expected_ast = ast_utils.create_summation_node(
				{ type = "variable", name = "k" },
				{ type = "number", value = 1 },
				{ type = "symbol", name = "infinity" },
				{ type = "number", value = 1 }
			)

			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse definite integrals with infinity bounds", function()
			local input = "\\int_{0}^{\\infty} 1 \\mathrm{d}x"
			local expected_ast = ast_utils.create_definite_integral_node(
				{ type = "number", value = 1 },
				{ type = "variable", name = "x" },
				{ type = "number", value = 0 },
				{ type = "symbol", name = "infinity" }
			)

			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse partial derivative of a product: \\frac{\\partial}{\\partial x} (x^2 y)", function()
			local input = "\\frac{\\partial}{\\partial x} (x^2 y)"
			local expected_ast = ast_utils.create_partial_derivative_node(
				ast_utils.create_binary_operation_node(
					"*",
					ast_utils.create_superscript_node({ type = "variable", name = "x" }, { type = "number", value = 2 }),
					{ type = "variable", name = "y" }
				),
				{ type = "number", value = 1 },
				{
					ast_utils.create_differentiation_term_node({ type = "variable", name = "x" }, { type = "number", value = 1 }),
				}
			)
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse arithmetic operation on two calculus terms: \\int x dx + \\lim_{x \\to 0} x^2", function()
			local input = "\\int x dx + \\lim_{x \\to 0} x^2"
			local expected_ast = ast_utils.create_binary_operation_node(
				"+",
				ast_utils.create_indefinite_integral_node({ type = "variable", name = "x" }, { type = "variable", name = "x" }),
				ast_utils.create_limit_node(
					{ type = "variable", name = "x" },
					{ type = "number", value = 0 },
					ast_utils.create_superscript_node({ type = "variable", name = "x" }, { type = "number", value = 2 })
				)
			)
			assert.are.same(expected_ast, parse_input(input))
		end)
	end)

	describe("solve system input", function()
		it("parses multiline LaTeX systems with aligned equals", function()
			local input = [[
                                x^2 + y^2 &= 1 \\\\
                                x^2 - 2y^2 &= 0
                        ]]

			local res = parser.parse(input, { preserve_newlines = true, allow_multiple_relations = true })
			assert.is_not_nil(res)
			assert.is_table(res.series)
			assert.are.equal(1, #res.series)

			local system_capture = res.series[1]
			assert.are.equal("solve_system_equations_capture", system_capture.type)
			assert.are.equal(2, #system_capture.equations)
			assert.are.equal("Equality", system_capture.equations[1].type)
			assert.are.equal("Equality", system_capture.equations[2].type)
		end)
	end)

	describe("differential equations input", function()
		it("parses ODEs with initial conditions using alignment separators", function()
			local input = "y'' + y &= 0 \\\\\n y(0) &= 1 \\\\\n y'(0) &= 0"

			local res = parser.parse(input, { allow_multiple_relations = true })
			assert.is_not_nil(res)
			assert.is_table(res.series)
			assert.are.equal(3, #res.series)
			assert.are.equal("ode", res.series[1].type)
			assert.are.equal("Equality", res.series[2].type)
			assert.are.equal("Equality", res.series[3].type)
		end)
	end)
end)
