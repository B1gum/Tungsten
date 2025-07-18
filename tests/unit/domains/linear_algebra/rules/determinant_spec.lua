-- tungsten/tests/unit/domains/linear_algebra/rules/determinant_spec.lua
-- Unit tests for the determinant parsing rule.

local lpeg = require("lpeglabel")
local P, C, R, S = lpeg.P, lpeg.C, lpeg.R, lpeg.S

local DeterminantRule

local mock_tokenizer_module
local mock_ast_module
local modules_to_reset = {
	"tungsten.domains.linear_algebra.rules.determinant",
	"tungsten.core.tokenizer",
	"tungsten.core.ast",
}

local test_grammar_table_definition
local compiled_test_grammar

local function placeholder_expr_node(val_str, original_type)
	return { type = "expression_placeholder", value = val_str, original_type = original_type }
end

local function matrix_node(env_type_str)
	return { type = "matrix_placeholder", env = env_type_str }
end

describe("Linear Algebra Determinant Rule: tungsten.domains.linear_algebra.rules.determinant", function()
	before_each(function()
		for _, name in ipairs(modules_to_reset) do
			package.loaded[name] = nil
		end

		mock_tokenizer_module = {
			space = S(" \t\n\r") ^ 0,
			det_command = P("\\det") / function()
				return { type = "det_command_token" }
			end,
			vbar = P("|") * -P("|") / function()
				return { type = "vbar_token" }
			end,
			lparen = P("("),
			rparen = P(")"),
			variable = C(R("AZ", "az") * (R("AZ", "az", "09") ^ 0)) / function(s)
				return placeholder_expr_node(s, "variable")
			end,
			number = C(R("09") ^ 1) / function(s)
				return placeholder_expr_node(s, "number")
			end,
			matrix_env_begin = (P("\\begin{pmatrix}") + P("\\begin{bmatrix}")) / function(env)
				local type_str = env:match("{(%a+matrix)}")
				return { type = "matrix_begin_token", env_type = type_str }
			end,
			matrix_env_end = P("\\end{pmatrix}") + P("\\end{bmatrix}"),
			ampersand = P("&"),
			double_backslash = P("\\\\"),
		}
		package.loaded["tungsten.core.tokenizer"] = mock_tokenizer_module

		mock_ast_module = {
			create_determinant_node = function(expression_ast)
				return {
					type = "determinant",
					expression = expression_ast,
				}
			end,
			create_matrix_node = function(rows, env_type)
				return matrix_node(env_type)
			end,
		}
		package.loaded["tungsten.core.ast"] = mock_ast_module

		DeterminantRule = require("tungsten.domains.linear_algebra.rules.determinant")

		local matrix_rule_placeholder = P("\\begin{pmatrix}")
			* (mock_tokenizer_module.variable + mock_tokenizer_module.number) ^ 0
			* P("\\end{pmatrix}")
			/ function()
				return matrix_node("pmatrix")
			end

		test_grammar_table_definition = {
			"TestEntryPoint",
			TestEntryPoint = DeterminantRule * -P(1),
			Expression = matrix_rule_placeholder + mock_tokenizer_module.variable + mock_tokenizer_module.number,
		}
		compiled_test_grammar = lpeg.P(test_grammar_table_definition)
	end)

	after_each(function()
		for _, name in ipairs(modules_to_reset) do
			package.loaded[name] = nil
		end
	end)

	local function parse_input(input_str)
		assert(compiled_test_grammar, "Test grammar was not compiled for test.")
		return lpeg.match(compiled_test_grammar, input_str)
	end

	describe("Valid determinant notations", function()
		it("should parse \\det(A)", function()
			local input = "\\det(A)"
			local expected_ast = {
				type = "determinant",
				expression = placeholder_expr_node("A", "variable"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse |B|", function()
			local input = "|B|"
			local expected_ast = {
				type = "determinant",
				expression = placeholder_expr_node("B", "variable"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse \\det(MyMatrix) with multi-character variable", function()
			local input = "\\det(MyMatrix)"
			local expected_ast = {
				type = "determinant",
				expression = placeholder_expr_node("MyMatrix", "variable"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse |VarName123| with alphanumeric variable", function()
			local input = "|VarName123|"
			local expected_ast = {
				type = "determinant",
				expression = placeholder_expr_node("VarName123", "variable"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse with spaces: \\det (  A  )", function()
			local input = "\\det (  A  )"
			local expected_ast = {
				type = "determinant",
				expression = placeholder_expr_node("A", "variable"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse with spaces: |  B  |", function()
			local input = "|  B  |"
			local expected_ast = {
				type = "determinant",
				expression = placeholder_expr_node("B", "variable"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse \\det(\\begin{pmatrix}a\\end{pmatrix})", function()
			local input = "\\det(\\begin{pmatrix}a\\end{pmatrix})"
			local expected_ast = {
				type = "determinant",
				expression = matrix_node("pmatrix"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse |\\begin{pmatrix}b\\end{pmatrix}|", function()
			local input = "|\\begin{pmatrix}b\\end{pmatrix}|"
			local expected_ast = {
				type = "determinant",
				expression = matrix_node("pmatrix"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)
	end)

	describe("Invalid determinant notations", function()
		it("should not parse \\det A (missing parentheses)", function()
			assert.is_nil(parse_input("\\det A"))
		end)

		it("should not parse det(A) (missing backslash)", function()
			assert.is_nil(parse_input("det(A)"))
		end)

		it("should not parse |A (missing closing bar)", function()
			assert.is_nil(parse_input("|A"))
		end)

		it("should not parse A| (missing opening bar)", function()
			assert.is_nil(parse_input("A|"))
		end)

		it("should not parse \\det[A] (wrong brackets)", function()
			assert.is_nil(parse_input("\\det[A]"))
		end)

		it("should not parse \\det (empty parentheses)", function()
			assert.is_nil(parse_input("\\det()"))
		end)

		it("should not parse || (empty vertical bars)", function()
			assert.is_nil(parse_input("||"))
		end)

		it("should not parse \\det ( A (mismatched parentheses)", function()
			assert.is_nil(parse_input("\\det ( A"))
		end)

		it("should not parse | A ( B ) | (nested parentheses inside simple var, our Expression mock is simple)", function()
			assert.is_nil(parse_input("| A(B) |"))
		end)
	end)
end)
