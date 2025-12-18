-- tests/unit/domains/calculus/rules/sum_spec.lua

local lpeg = require("lpeglabel")
local P, C, R, S = lpeg.P, lpeg.C, lpeg.R, lpeg.S

local SumRule

local mock_tokenizer_module
local mock_ast_module
local modules_to_reset = {
	"tungsten.domains.calculus.rules.sum",
	"tungsten.core.tokenizer",
	"tungsten.core.ast",
}

local test_grammar_table_definition
local compiled_test_grammar

local function placeholder_node(node_type, val_str, original_type_if_known)
	return { type = node_type, value_str = val_str, original_type = original_type_if_known or node_type }
end

describe("Calculus Sum Rule: tungsten.domains.calculus.rules.sum", function()
	before_each(function()
		for _, name in ipairs(modules_to_reset) do
			package.loaded[name] = nil
		end

		mock_tokenizer_module = {
			space = S(" \t\n\r") ^ 0,
			lbrace = P("{"),
			rbrace = P("}"),
			variable = C(R("az", "AZ") * (R("az", "AZ", "09") ^ 0)) / function(name_str)
				return { type = "variable", name = name_str }
			end,
			number = C(R("09") ^ 1 * (P(".") * R("09") ^ 1) ^ -1) / function(num_str)
				return { type = "number", value = tonumber(num_str) }
			end,
		}
		package.loaded["tungsten.core.tokenizer"] = mock_tokenizer_module

		mock_ast_module = {
			node = function(type, fields)
				fields = fields or {}
				fields.type = type
				return fields
			end,

			create_summation_node = function(index_variable, start_expression, end_expression, body_expression)
				return {
					type = "summation",
					index_variable = index_variable,
					start_expression = start_expression,
					end_expression = end_expression,
					body_expression = body_expression,
				}
			end,
		}
		package.loaded["tungsten.core.ast"] = mock_ast_module

		SumRule = require("tungsten.domains.calculus.rules.sum")

		test_grammar_table_definition = {
			"TestEntryPoint",
			TestEntryPoint = SumRule * -P(1),

			Expression = (P("i^2") / function()
				return placeholder_node("placeholder_expr", "i^2", "power_i2")
			end + P("k^3") / function()
				return placeholder_node("placeholder_expr", "k^3", "power_k3")
			end + P("1/n") / function()
				return placeholder_node("placeholder_expr", "1/n", "fraction_1n")
			end + P("a_k") / function()
				return placeholder_node("placeholder_expr", "a_k", "subscript_ak")
			end + P("\\alpha") / function()
				return { type = "symbol", name = "alpha" }
			end + P("\\infty") / function()
				return { type = "symbol", name = "infinity" }
			end + mock_tokenizer_module.number + mock_tokenizer_module.variable),
		}
		compiled_test_grammar = lpeg.P(test_grammar_table_definition)
	end)

	after_each(function()
		for _, name in ipairs(modules_to_reset) do
			package.loaded[name] = nil
		end
	end)

	local function parse_input(input_str)
		assert(compiled_test_grammar, "Test grammar was not compiled for test")
		return lpeg.match(compiled_test_grammar, input_str)
	end

	describe("Basic Sum Parsing", function()
		it("should parse \\sum_{i=0}^{N} i^2 (unbraced body)", function()
			local input = "\\sum_{i=0}^{N} i^2"
			local expected_ast = {
				type = "summation",
				index_variable = { type = "variable", name = "i" },
				start_expression = { type = "number", value = 0 },
				end_expression = { type = "variable", name = "N" },
				body_expression = placeholder_node("placeholder_expr", "i^2", "power_i2"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse \\sum_{k=1}^{10} {k^3} (braced body)", function()
			local input = "\\sum_{k=1}^{10} {k^3}"
			local expected_ast = {
				type = "summation",
				index_variable = { type = "variable", name = "k" },
				start_expression = { type = "number", value = 1 },
				end_expression = { type = "number", value = 10 },
				body_expression = placeholder_node("placeholder_expr", "k^3", "power_k3"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse with variable start/end: \\sum_{n=m}^{M} 1/n", function()
			local input = "\\sum_{n=m}^{M} 1/n"
			local expected_ast = {
				type = "summation",
				index_variable = { type = "variable", name = "n" },
				start_expression = { type = "variable", name = "m" },
				end_expression = { type = "variable", name = "M" },
				body_expression = placeholder_node("placeholder_expr", "1/n", "fraction_1n"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse infinite upper bounds: \\sum_{k=1}^{\\infty} k^3", function()
			local input = "\\sum_{k=1}^{\\infty} k^3"
			local expected_ast = {
				type = "summation",
				index_variable = { type = "variable", name = "k" },
				start_expression = { type = "number", value = 1 },
				end_expression = { type = "symbol", name = "infinity" },
				body_expression = placeholder_node("placeholder_expr", "k^3", "power_k3"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse with Greek letter index: \\sum_{\\alpha=1}^{5} a_k", function()
			local input = "\\sum_{alpha=1}^{5} a_k"
			local expected_ast = {
				type = "summation",
				index_variable = { type = "variable", name = "alpha" },
				start_expression = { type = "number", value = 1 },
				end_expression = { type = "number", value = 5 },
				body_expression = placeholder_node("placeholder_expr", "a_k", "subscript_ak"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)
	end)

	describe("Spacing Variations", function()
		it("should parse with extra spaces: \\sum _ { i = 0 } ^ { N } { i^2 }", function()
			local input = "\\sum _ { i = 0 } ^ { N } { i^2 }"
			local expected_ast = {
				type = "summation",
				index_variable = { type = "variable", name = "i" },
				start_expression = { type = "number", value = 0 },
				end_expression = { type = "variable", name = "N" },
				body_expression = placeholder_node("placeholder_expr", "i^2", "power_i2"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse with minimal spaces: \\sum_{i=0}^{N}i^2", function()
			local input = "\\sum_{i=0}^{N}i^2"
			local expected_ast = {
				type = "summation",
				index_variable = { type = "variable", name = "i" },
				start_expression = { type = "number", value = 0 },
				end_expression = { type = "variable", name = "N" },
				body_expression = placeholder_node("placeholder_expr", "i^2", "power_i2"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)
	end)

	describe("Invalid Syntax", function()
		it("should not parse if \\sum is missing: _{i=0}^{N} i^2", function()
			assert.is_nil(parse_input("_{i=0}^{N} i^2"))
		end)
		it("should not parse if subscript is missing: \\sum^{N} i^2", function()
			assert.is_nil(parse_input("\\sum^{N} i^2"))
		end)
		it("should not parse if superscript is missing: \\sum_{i=0} i^2", function()
			assert.is_nil(parse_input("\\sum_{i=0} i^2"))
		end)
		it("should not parse if '=' is missing in subscript: \\sum_{i 0}^{N} i^2", function()
			assert.is_nil(parse_input("\\sum_{i 0}^{N} i^2"))
		end)
		it("should not parse if start expression is missing: \\sum_{i=}^{N} i^2", function()
			assert.is_nil(parse_input("\\sum_{i=}^{N} i^2"))
		end)
		it("should not parse if index variable is missing: \\sum_{=0}^{N} i^2", function()
			assert.is_nil(parse_input("\\sum_{=0}^{N} i^2"))
		end)
		it("should not parse if end expression is missing: \\sum_{i=0}^{} i^2", function()
			assert.is_nil(parse_input("\\sum_{i=0}^{} i^2"))
		end)
		it("should not parse if body expression is missing: \\sum_{i=0}^{N}", function()
			assert.is_nil(parse_input("\\sum_{i=0}^{N}"))
		end)
		it("should not parse if subscript braces are mismatched: \\sum_{i=0^{N} i^2", function()
			assert.is_nil(parse_input("\\sum_{i=0^{N} i^2"))
		end)
		it("should not parse if superscript braces are mismatched: \\sum_{i=0}^{N {i^2}", function()
			assert.is_nil(parse_input("\\sum_{i=0}^{N {i^2}"))
		end)
	end)
end)
