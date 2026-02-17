-- tungsten/tests/unit/domains/linear_algebra/rules/rank_spec.lua

local lpeg = vim.lpeg
local P, C, R, S = lpeg.P, lpeg.C, lpeg.R, lpeg.S

local RankRule

local mock_tokenizer_module
local mock_ast_module
local modules_to_reset = {
	"tungsten.domains.linear_algebra.rules.rank",
	"tungsten.core.tokenizer",
	"tungsten.core.ast",
}

local test_grammar_table_definition
local compiled_test_grammar

local function placeholder_expr_node(val_str, type_str_override)
	local node_type = type_str_override or "expression_placeholder"
	if type_str_override == "variable" then
		return { type = "variable", name = val_str }
	elseif type_str_override == "matrix" then
		return { type = "matrix_placeholder", content = val_str }
	end
	return { type = node_type, value = val_str }
end

describe("Linear Algebra Rank Rule: tungsten.domains.linear_algebra.rules.rank", function()
	before_each(function()
		for _, name in ipairs(modules_to_reset) do
			package.loaded[name] = nil
		end

		mock_tokenizer_module = {
			space = S(" \t\n\r") ^ 0,
			lparen = P("("),
			rparen = P(")"),
			variable = C(R("AZ", "az") * (R("AZ", "az", "09") ^ 0)) / function(s)
				return placeholder_expr_node(s, "variable")
			end,
			matrix_placeholder_rule = P("\\begin{pmatrix}")
				* C((P(1) - P("\\end{pmatrix}")) ^ 0)
				* P("\\end{pmatrix}")
				/ function(matrix_content_str)
					return placeholder_expr_node(matrix_content_str, "matrix")
				end,
		}
		package.loaded["tungsten.core.tokenizer"] = mock_tokenizer_module

		mock_ast_module = {
			create_rank_node = function(expression_ast)
				return {
					type = "rank",
					expression = expression_ast,
				}
			end,
		}
		package.loaded["tungsten.core.ast"] = mock_ast_module

		RankRule = require("tungsten.domains.linear_algebra.rules.rank")

		test_grammar_table_definition = {
			"TestEntryPoint",
			TestEntryPoint = RankRule * -P(1),
			Expression = mock_tokenizer_module.variable + mock_tokenizer_module.matrix_placeholder_rule,
		}
		compiled_test_grammar = lpeg.P(test_grammar_table_definition)
	end)

	after_each(function()
		for _, name in ipairs(modules_to_reset) do
			package.loaded[name] = nil
		end
	end)

	local function parse_input(input_str)
		assert(compiled_test_grammar, "Test grammar was not compiled for this test run.")
		return lpeg.match(compiled_test_grammar, input_str)
	end

	describe("Valid rank notations", function()
		it("should parse \\mathrm{rank}(A)", function()
			local input = "\\mathrm{rank}(A)"
			local expected_ast = {
				type = "rank",
				expression = placeholder_expr_node("A", "variable"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse \\text{rank}(B)", function()
			local input = "\\text{rank}(B)"
			local expected_ast = {
				type = "rank",
				expression = placeholder_expr_node("B", "variable"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse \\mathrm{rank}(\\begin{pmatrix}1&0\\\\0&1\\end{pmatrix}) (mocked matrix)", function()
			local input = "\\mathrm{rank}(\\begin{pmatrix}1&0\\\\0&1\\end{pmatrix})"
			local expected_ast = {
				type = "rank",
				expression = placeholder_expr_node("1&0\\\\0&1", "matrix"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse with spaces: \\mathrm{rank} ( MyMatrix )", function()
			local input = "\\mathrm{rank} ( MyMatrix )"
			local expected_ast = {
				type = "rank",
				expression = placeholder_expr_node("MyMatrix", "variable"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)
	end)

	describe("Invalid rank notations", function()
		it("should not parse \\rank(A) (missing text/mathrm)", function()
			assert.is_nil(parse_input("\\rank(A)"))
		end)

		it("should not parse \\mathrm{rank}A (missing parentheses)", function()
			assert.is_nil(parse_input("\\mathrm{rank}A"))
		end)

		it("should not parse \\mathrm{rank}( (missing closing parenthesis or content)", function()
			assert.is_nil(parse_input("\\mathrm{rank}("))
		end)
		it("should not parse \\mathrm{rank}() (empty content)", function()
			assert.is_nil(parse_input("\\mathrm{rank}()"))
		end)
	end)
end)
