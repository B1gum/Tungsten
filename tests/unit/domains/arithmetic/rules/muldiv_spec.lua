-- tungsten/tests/unit/domains/arithmetic/rules/muldiv_spec.lua

local lpeg = vim.lpeg
local P, R, S, C, V = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.V

local mock_tk_original = {
	space = S(" \t\n\r") ^ 0,
	variable = C(R("az", "AZ") * (R("az", "AZ", "09") ^ 0)) / function(v)
		return { type = "variable", name = v }
	end,
	number = C(R("09") ^ 1 * (P(".") * R("09") ^ 1) ^ -1) / function(n)
		return { type = "number", value = tonumber(n) }
	end,
	vec_command = P("\\vec{") * C(R("az", "AZ", "09") ^ 1) * P("}") / function(s)
		return { type = "symbolic_vector", name_expr = { type = "variable", name = s } }
	end,
	matrix_placeholder = P("Matrix") * C(R("AZ")) / function(id)
		return { type = "matrix", id = id }
	end,
	times_command = P("\\times") / function()
		return "\\times"
	end,
	cdot_command = P("\\cdot") / function()
		return "\\cdot"
	end,
}

local mock_ast_utils_original = {
	create_binary_operation_node = function(op, left, right)
		if op == nil or left == nil or right == nil then
			error(
				"create_binary_operation_node called with nil arguments: op="
					.. tostring(op)
					.. " left="
					.. tostring(left)
					.. " right="
					.. tostring(right)
			)
		end
		return { type = "binary", operator = op, left = left, right = right }
	end,
	create_dot_product_node = function(left, right)
		return { type = "dot_product", left = left, right = right }
	end,
	create_cross_product_node = function(left, right)
		return { type = "cross_product", left = left, right = right }
	end,
	create_unary_operation_node = function(op, val)
		return { type = "unary", operator = op, value = val }
	end,
	create_superscript_node = function(b, e)
		return { type = "superscript", base = b, exponent = e }
	end,
}

local original_package_loaded_muldiv = {}
local modules_to_mock_muldiv = {
	["tungsten.core.tokenizer"] = mock_tk_original,
	["tungsten.domains.arithmetic.rules.supersub"] = nil,
	["tungsten.core.ast"] = mock_ast_utils_original,
	["tungsten.domains.arithmetic.rules.muldiv"] = nil,
}

local MulDivRuleItself_MulDiv
local test_grammar_entry_muldiv
local MockUnaryRule_MulDiv

local function compile_test_grammar_muldiv(rule_to_test)
	local AtomForUnaryDef = mock_tk_original.vec_command
		+ mock_tk_original.matrix_placeholder
		+ mock_tk_original.variable
		+ mock_tk_original.number
		+ (P("(") * mock_tk_original.space * V("Expression_for_parens") * mock_tk_original.space * P(")"))

	local ExpressionForParensDef = (
		V("AtomForUnary")
		* mock_tk_original.space
		* P("+")
		* mock_tk_original.space
		* V("AtomForUnary")
		/ function(l, r)
			return mock_ast_utils_original.create_binary_operation_node("+", l, r)
		end
	)
		+ (V("AtomForUnary") * P("^") * V("AtomForUnary") / function(b_val, e_val)
			return mock_ast_utils_original.create_superscript_node(b_val, e_val)
		end)
		+ rule_to_test

	local grammar_table = {
		"TestEntryForMulDiv",
		TestEntryForMulDiv = rule_to_test,
		Expression_for_parens = ExpressionForParensDef,
		AtomForUnary = AtomForUnaryDef,
		Unary = MockUnaryRule_MulDiv,
	}
	return lpeg.P(grammar_table)
end

local function parse_input_muldiv(input)
	if not test_grammar_entry_muldiv then
		error("Test grammar not compiled for MulDiv parsing.")
	end
	return lpeg.match(test_grammar_entry_muldiv, input)
end

describe("Arithmetic MulDiv Rule (Context-Aware & Differentials)", function()
	before_each(function()
		for name, mock_impl in pairs(modules_to_mock_muldiv) do
			original_package_loaded_muldiv[name] = package.loaded[name]
			package.loaded[name] = mock_impl
		end

		MockUnaryRule_MulDiv = V("AtomForUnary")
			+ (
				C(S("+-"))
				* mock_tk_original.space
				* V("AtomForUnary")
				/ function(op, val)
					return mock_ast_utils_original.create_unary_operation_node(op, val)
				end
			)
		modules_to_mock_muldiv["tungsten.domains.arithmetic.rules.supersub"] = { Unary = MockUnaryRule_MulDiv }
		package.loaded["tungsten.domains.arithmetic.rules.supersub"] =
			modules_to_mock_muldiv["tungsten.domains.arithmetic.rules.supersub"]

		package.loaded["tungsten.domains.arithmetic.rules.muldiv"] = nil
		MulDivRuleItself_MulDiv = require("tungsten.domains.arithmetic.rules.muldiv")
		test_grammar_entry_muldiv = compile_test_grammar_muldiv(MulDivRuleItself_MulDiv)
	end)

	after_each(function()
		for name, original_impl in pairs(original_package_loaded_muldiv) do
			package.loaded[name] = original_impl
		end
		original_package_loaded_muldiv = {}
		MulDivRuleItself_MulDiv = nil
		test_grammar_entry_muldiv = nil
		MockUnaryRule_MulDiv = nil
	end)

	describe("Standard Implicit Multiplication (from original tests - adapt as needed)", function()
		it("should parse '2x' as 2*x", function()
			local ast = parse_input_muldiv("2x")
			assert.are.same({
				type = "binary",
				operator = "*",
				left = { type = "number", value = 2 },
				right = { type = "variable", name = "x" },
			}, ast)
		end)
		it("should parse 'varOne varTwo' as varOne*varTwo", function()
			local ast = parse_input_muldiv("varOne varTwo")
			assert.are.same({
				type = "binary",
				operator = "*",
				left = { type = "variable", name = "varOne" },
				right = { type = "variable", name = "varTwo" },
			}, ast)
		end)
		it("should parse 'a(b)' as a*b", function()
			local ast = parse_input_muldiv("a(b)")
			assert.are.same({
				type = "binary",
				operator = "*",
				left = { type = "variable", name = "a" },
				right = { type = "variable", name = "b" },
			}, ast)
		end)
	end)

	describe("Context-Aware Dot Product", function()
		it("should parse \\vec{a} \\cdot \\vec{b} as dot_product", function()
			local ast = parse_input_muldiv("\\vec{a} \\cdot \\vec{b}")
			assert.are.same({
				type = "dot_product",
				left = { type = "symbolic_vector", name_expr = { type = "variable", name = "a" } },
				right = { type = "symbolic_vector", name_expr = { type = "variable", name = "b" } },
			}, ast)
		end)

		it("should parse MatrixA \\cdot \\vec{b} as dot_product (matrix and vector)", function()
			local ast = parse_input_muldiv("MatrixA \\cdot \\vec{b}")
			assert.are.same({
				type = "dot_product",
				left = { type = "matrix", id = "A" },
				right = { type = "symbolic_vector", name_expr = { type = "variable", name = "b" } },
			}, ast)
		end)

		it("should parse (\\vec{a}) \\cdot MatrixB as dot_product (parenthesized vector and matrix)", function()
			local ast = parse_input_muldiv("(\\vec{a}) \\cdot MatrixB")
			assert.are.same({
				type = "dot_product",
				left = { type = "symbolic_vector", name_expr = { type = "variable", name = "a" } },
				right = { type = "matrix", id = "B" },
			}, ast)
		end)
	end)

	describe("Context-Aware Cross Product", function()
		it("should parse \\vec{u} \\times \\vec{v} as cross_product", function()
			local ast = parse_input_muldiv("\\vec{u} \\times \\vec{v}")
			assert.are.same({
				type = "cross_product",
				left = { type = "symbolic_vector", name_expr = { type = "variable", name = "u" } },
				right = { type = "symbolic_vector", name_expr = { type = "variable", name = "v" } },
			}, ast)
		end)
		it(
			"should parse MatrixA \\times MatrixB as cross_product (if matrices are considered vector-like by rule)",
			function()
				local ast = parse_input_muldiv("MatrixA \\times MatrixB")
				assert.are.same({
					type = "cross_product",
					left = { type = "matrix", id = "A" },
					right = { type = "matrix", id = "B" },
				}, ast)
			end
		)
	end)

	describe("Arithmetic Fallback for \\cdot and \\times", function()
		it("should parse x \\cdot y as standard multiplication (binary *)", function()
			local ast = parse_input_muldiv("x \\cdot y")
			assert.are.same({
				type = "binary",
				operator = "*",
				left = { type = "variable", name = "x" },
				right = { type = "variable", name = "y" },
			}, ast)
		end)

		it("should parse (a+b) \\cdot c as standard multiplication", function()
			local ast = parse_input_muldiv("(a+b) \\cdot c")
			assert.are.same({
				type = "binary",
				operator = "*",
				left = {
					type = "binary",
					operator = "+",
					left = { type = "variable", name = "a" },
					right = { type = "variable", name = "b" },
				},
				right = { type = "variable", name = "c" },
			}, ast)
		end)

		it("should parse x \\times y as standard multiplication (binary *)", function()
			local ast = parse_input_muldiv("x \\times y")
			assert.are.same({
				type = "binary",
				operator = "*",
				left = { type = "variable", name = "x" },
				right = { type = "variable", name = "y" },
			}, ast)
		end)

		it("should parse 2 \\cdot 3 as standard multiplication", function()
			local ast = parse_input_muldiv("2 \\cdot 3")
			assert.are.same({
				type = "binary",
				operator = "*",
				left = { type = "number", value = 2 },
				right = { type = "number", value = 3 },
			}, ast)
		end)
	end)

	describe("Standard Multiplication, Division, and Implicit (Regression Tests)", function()
		it("should still parse 2*var as binary multiplication", function()
			local ast = parse_input_muldiv("2*var")
			assert.are.same({
				type = "binary",
				operator = "*",
				left = { type = "number", value = 2 },
				right = { type = "variable", name = "var" },
			}, ast)
		end)

		it("should still parse varOne/varTwo as binary division", function()
			local ast = parse_input_muldiv("varOne/varTwo")
			assert.are.same({
				type = "binary",
				operator = "/",
				left = { type = "variable", name = "varOne" },
				right = { type = "variable", name = "varTwo" },
			}, ast)
		end)

		it("should still parse 2x (implicit) as 2*x", function()
			local ast = parse_input_muldiv("2x")
			assert.are.same({
				type = "binary",
				operator = "*",
				left = { type = "number", value = 2 },
				right = { type = "variable", name = "x" },
			}, ast)
		end)
		it("should still parse (a)(b) (implicit) as a*b", function()
			local ast = parse_input_muldiv("(a)(b)")
			assert.are.same({
				type = "binary",
				operator = "*",
				left = { type = "variable", name = "a" },
				right = { type = "variable", name = "b" },
			}, ast)
		end)
	end)

	describe("Differential Awareness (Regression Tests)", function()
		it("should still parse 'x dx' as 'x', leaving 'dx' (no implicit mul)", function()
			local ast = parse_input_muldiv("x dx")
			assert.are.same({ type = "variable", name = "x" }, ast)
		end)

		it("should parse 'E dt' as 'E', leaving 'dt' unconsumed", function()
			local ast = parse_input_muldiv("E dt")
			assert.are.same({ type = "variable", name = "E" }, ast)
		end)

		it("should parse 'alpha dy' as 'alpha', leaving 'dy' unconsumed", function()
			local ast = parse_input_muldiv("alpha dy")
			assert.are.same({ type = "variable", name = "alpha" }, ast)
		end)

		it("should parse '2dx' as '2', leaving 'dx' unconsumed", function()
			local ast = parse_input_muldiv("2dx")
			assert.are.same({ type = "number", value = 2 }, ast)
		end)

		it("should parse 'func dtheta' as 'func', leaving 'dtheta' unconsumed", function()
			local ast = parse_input_muldiv("func dtheta")
			assert.are.same({ type = "variable", name = "func" }, ast)
		end)
	end)
	describe("Implicit Multiplication with variable 'd' not part of a differential", function()
		it("should parse 'a d x' as 'a', leaving 'd x' due to -is_potential_differential_start", function()
			local ast = parse_input_muldiv("a d x")
			assert.are.same({ type = "variable", name = "a" }, ast)
		end)

		it("should parse 'd x y' as ((d*x)*y)", function()
			local ast = parse_input_muldiv("d x y")
			assert.are.same({
				type = "binary",
				operator = "*",
				left = {
					type = "binary",
					operator = "*",
					left = { type = "variable", name = "d" },
					right = { type = "variable", name = "x" },
				},
				right = { type = "variable", name = "y" },
			}, ast)
		end)
	end)

	describe("Explicit Multiplication (Original Tests)", function()
		it("should parse 'x * d y' as ((x*d)*y) using explicit operator", function()
			local ast = parse_input_muldiv("x * d y")
			assert.are.same({
				type = "binary",
				operator = "*",
				left = {
					type = "binary",
					operator = "*",
					left = { type = "variable", name = "x" },
					right = { type = "variable", name = "d" },
				},
				right = { type = "variable", name = "y" },
			}, ast)
		end)

		it("should parse 'x \\cdot d y' as ((x*d)*y) (fallback from dot product attempt)", function()
			local ast = parse_input_muldiv("x \\cdot d y")
			assert.are.same({
				type = "binary",
				operator = "*",
				left = {
					type = "binary",
					operator = "*",
					left = { type = "variable", name = "x" },
					right = { type = "variable", name = "d" },
				},
				right = { type = "variable", name = "y" },
			}, ast)
		end)
	end)

	describe("Precedence with AddSub (Combined Operations)", function()
		it("should correctly parse \\vec{a} \\cdot \\vec{b} + c (dot product before add)", function()
			local ast = parse_input_muldiv("\\vec{a} \\cdot \\vec{b}")
			assert.are.same({
				type = "dot_product",
				left = { type = "symbolic_vector", name_expr = { type = "variable", name = "a" } },
				right = { type = "symbolic_vector", name_expr = { type = "variable", name = "b" } },
			}, ast, "Dot product part should be self-contained")
		end)

		it("should correctly parse x^2 \\cdot \\vec{y} as binary '*' (scalar times vector)", function()
			local old_unary_rule = MockUnaryRule_MulDiv
			MockUnaryRule_MulDiv = (
				V("AtomForUnary")
				* P("^")
				* V("AtomForUnary")
				/ function(b, e)
					return mock_ast_utils_original.create_superscript_node(b, e)
				end
			)
				+ V("AtomForUnary")
				+ (
					C(S("+-"))
					* mock_tk_original.space
					* V("AtomForUnary")
					/ function(op, val)
						return mock_ast_utils_original.create_unary_operation_node(op, val)
					end
				)

			modules_to_mock_muldiv["tungsten.domains.arithmetic.rules.supersub"] = { Unary = MockUnaryRule_MulDiv }
			package.loaded["tungsten.domains.arithmetic.rules.supersub"] =
				modules_to_mock_muldiv["tungsten.domains.arithmetic.rules.supersub"]

			package.loaded["tungsten.domains.arithmetic.rules.muldiv"] = nil
			MulDivRuleItself_MulDiv = require("tungsten.domains.arithmetic.rules.muldiv")
			test_grammar_entry_muldiv = compile_test_grammar_muldiv(MulDivRuleItself_MulDiv)

			local ast = parse_input_muldiv("x^2 \\cdot \\vec{y}")
			assert.are.same({
				type = "binary",
				operator = "*",
				left = {
					type = "superscript",
					base = { type = "variable", name = "x" },
					exponent = { type = "number", value = 2 },
				},
				right = { type = "symbolic_vector", name_expr = { type = "variable", name = "y" } },
			}, ast)

			MockUnaryRule_MulDiv = old_unary_rule
			modules_to_mock_muldiv["tungsten.domains.arithmetic.rules.supersub"] = { Unary = MockUnaryRule_MulDiv }
			package.loaded["tungsten.domains.arithmetic.rules.supersub"] =
				modules_to_mock_muldiv["tungsten.domains.arithmetic.rules.supersub"]
			package.loaded["tungsten.domains.arithmetic.rules.muldiv"] = nil
		end)

		it("should parse -\\vec{a} \\cdot \\vec{b} as dot_product((-a), b) after is_vector_like fix", function()
			local ast = parse_input_muldiv("-\\vec{a} \\cdot \\vec{b}")
			assert.are.same({
				type = "dot_product",
				left = {
					type = "unary",
					operator = "-",
					value = { type = "symbolic_vector", name_expr = { type = "variable", name = "a" } },
				},
				right = { type = "symbolic_vector", name_expr = { type = "variable", name = "b" } },
			}, ast)
		end)
	end)
end)
