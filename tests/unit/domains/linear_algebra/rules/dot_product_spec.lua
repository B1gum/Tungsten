-- tests/unit/domains/linear_algebra/rules/dot_product_spec.lua
-- Unit tests for the dot product parsing rule.

local lpeg = require("lpeglabel")
local P, C, R, S = lpeg.P, lpeg.C, lpeg.R, lpeg.S

local DotProductRule

local mock_tokenizer_module
local mock_ast_module
local modules_to_reset = {
	"tungsten.domains.linear_algebra.rules.dot_product",
	"tungsten.core.tokenizer",
	"tungsten.core.ast",
}

local test_grammar_table_definition
local compiled_test_grammar

local function vector_node(name_str)
	return { type = "vector_placeholder", name = name_str }
end

local function variable_node(name_str)
	return { type = "variable", name = name_str }
end

describe("Linear Algebra Dot Product Rule: tungsten.domains.linear_algebra.rules.dot_product", function()
	before_each(function()
		for _, name in ipairs(modules_to_reset) do
			package.loaded[name] = nil
		end

		mock_tokenizer_module = {
			space = S(" \t\n\r") ^ 0,
			cdot_command = P("\\cdot") / function()
				return { type = "cdot_command_token" }
			end,
			variable = C(R("az", "AZ") * (R("az", "AZ", "09") ^ 0)) / function(s)
				return variable_node(s)
			end,
			vec_command = P("\\vec{") * C(R("az", "AZ") ^ 1) * P("}") / function(s)
				return vector_node(s)
			end,
		}
		package.loaded["tungsten.core.tokenizer"] = mock_tokenizer_module

		mock_ast_module = {
			create_dot_product_node = function(left_vector_ast, right_vector_ast)
				return {
					type = "dot_product",
					left = left_vector_ast,
					right = right_vector_ast,
				}
			end,
		}
		package.loaded["tungsten.core.ast"] = mock_ast_module

		DotProductRule = require("tungsten.domains.linear_algebra.rules.dot_product")

		test_grammar_table_definition = {
			"TestEntryPoint",
			TestEntryPoint = DotProductRule * -P(1),
			Expression = mock_tokenizer_module.vec_command + mock_tokenizer_module.variable,
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
		local result = lpeg.match(compiled_test_grammar, input_str)
		return result
	end

	describe("Valid dot product notations", function()
		it("should parse \\vec{a} \\cdot \\vec{b}", function()
			local input = "\\vec{a} \\cdot \\vec{b}"
			local expected_ast = {
				type = "dot_product",
				left = vector_node("a"),
				right = vector_node("b"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse x \\cdot y", function()
			local input = "x \\cdot y"
			local expected_ast = {
				type = "dot_product",
				left = variable_node("x"),
				right = variable_node("y"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse with varied spacing: \\vec{v1}   \\cdot   \\vec{v2}", function()
			local input = "\\vec{v1}   \\cdot   \\vec{v2}"

			mock_tokenizer_module.vec_command = P("\\vec{")
				* C(R("az", "AZ", "09") ^ 1)
				* P("}")
				/ function(s)
					return vector_node(s)
				end

			test_grammar_table_definition.Expression = mock_tokenizer_module.vec_command + mock_tokenizer_module.variable

			compiled_test_grammar = lpeg.P(test_grammar_table_definition)

			local expected_ast = {
				type = "dot_product",
				left = vector_node("v1"),
				right = vector_node("v2"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse without spaces: a\\cdot b", function()
			local input = "a\\cdot b"
			local expected_ast = {
				type = "dot_product",
				left = variable_node("a"),
				right = variable_node("b"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)
	end)

	describe("Invalid dot product notations", function()
		it("should not parse if \\cdot is missing: \\vec{a} \\vec{b}", function()
			assert.is_nil(parse_input("\\vec{a} \\vec{b}"))
		end)

		it("should not parse if left expression is missing: \\cdot \\vec{b}", function()
			assert.is_nil(parse_input("\\cdot \\vec{b}"))
		end)

		it("should not parse if right expression is missing: \\vec{a} \\cdot", function()
			assert.is_nil(parse_input("\\vec{a} \\cdot"))
		end)

		it("should not parse with incorrect command: \\vec{a} \\times \\vec{b}", function()
			assert.is_nil(parse_input("\\vec{a} \\times \\vec{b}"))
		end)
	end)
end)
