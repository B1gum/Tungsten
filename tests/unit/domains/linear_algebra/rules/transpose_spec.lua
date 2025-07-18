-- tungsten/tests/unit/domains/linear_algebra/rules/transpose_spec.lua

local lpeg = require("lpeglabel")
local P, V, C, R, S, Cf = lpeg.P, lpeg.V, lpeg.C, lpeg.R, lpeg.S, lpeg.Cf

local TransposeRule

local mock_tokenizer_module
local mock_ast_module
local modules_to_reset = {
	"tungsten.domains.linear_algebra.rules.transpose",
	"tungsten.core.tokenizer",
	"tungsten.core.ast",
}

local test_grammar_table_definition
local compiled_test_grammar

local function base_node(name_or_val, type)
	if type == "number" then
		return { type = "number", value = name_or_val }
	elseif type == "group" then
		return { type = "group_placeholder", content = name_or_val }
	else
		return { type = "variable", name = name_or_val }
	end
end

local function matrix_node_placeholder(name)
	return { type = "matrix_placeholder", name = name }
end

describe("Linear Algebra Transpose Rule: tungsten.domains.linear_algebra.rules.transpose", function()
	before_each(function()
		for _, name in ipairs(modules_to_reset) do
			package.loaded[name] = nil
		end

		mock_tokenizer_module = {
			space = S(" \t\n\r") ^ 0,
			lbrace = P("{"),
			rbrace = P("}"),
			variable = C(R("AZ", "az") * (R("AZ", "az", "09") ^ 0)) / function(s)
				if s == "T" then
					return { type = "variable", name = "T" }
				end
				if s == "intercal" then
					return { type = "variable", name = "intercal" }
				end
				return base_node(s, "variable")
			end,
			number = C(R("09") ^ 1 * (P(".") * R("09") ^ 1) ^ -1) / function(s)
				return base_node(tonumber(s), "number")
			end,
			lparen = P("("),
			rparen = P(")"),
		}
		package.loaded["tungsten.core.tokenizer"] = mock_tokenizer_module

		mock_ast_module = {
			create_transpose_node = function(expression_ast)
				return { type = "transpose", expression = expression_ast }
			end,
			create_superscript_node = function(b, e)
				return { type = "superscript", base = b, exponent = e }
			end,
			create_subscript_node = function(b, s)
				return { type = "subscript", base = b, subscript = s }
			end,
		}
		package.loaded["tungsten.core.ast"] = mock_ast_module

		TransposeRule = require("tungsten.domains.linear_algebra.rules.transpose")

		local exponent_content_ast_producer = mock_tokenizer_module.variable + mock_tokenizer_module.number

		local exponent_rule = (
			mock_tokenizer_module.lbrace
			* mock_tokenizer_module.space
			* exponent_content_ast_producer
			* mock_tokenizer_module.space
			* mock_tokenizer_module.rbrace
		) + exponent_content_ast_producer

		local mock_postfix_op = (
			P("^")
			* mock_tokenizer_module.space
			* exponent_rule
			/ function(the_exponent_ast)
				return function(base_ast)
					return mock_ast_module.create_superscript_node(base_ast, the_exponent_ast)
				end
			end
		)
			+ (
				P("_")
				* mock_tokenizer_module.space
				* exponent_rule
				/ function(the_subscript_ast)
					return function(base_ast)
						return mock_ast_module.create_subscript_node(base_ast, the_subscript_ast)
					end
				end
			)

		local mock_supsub_base_elements = mock_tokenizer_module.variable
			+ mock_tokenizer_module.number
			+ (mock_tokenizer_module.lparen * C(P("A+B")) * mock_tokenizer_module.rparen / function(c_str)
				return base_node(c_str, "group")
			end)
			+ (P("\\mymatrix") / function()
				return matrix_node_placeholder("mymatrix")
			end)

		local mock_supsub_rule = Cf(
			mock_supsub_base_elements * (mock_tokenizer_module.space * mock_postfix_op) ^ 0,
			function(acc_ast, op_builder_func)
				if op_builder_func then
					return op_builder_func(acc_ast)
				end
				return acc_ast
			end
		)

		test_grammar_table_definition = {
			"TestEntryPoint",
			TestEntryPoint = TransposeRule * -P(1),
			SupSub = mock_supsub_rule,
			AtomBase = exponent_content_ast_producer,
			Expression = V("SupSub"),
		}
		compiled_test_grammar = P(test_grammar_table_definition)
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

	describe("Valid transpose notations", function()
		it("should parse A^T", function()
			local input = "A^T"
			local expected_ast = {
				type = "transpose",
				expression = base_node("A", "variable"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse M^{\\intercal} (tested as M^intercal for mock)", function()
			local input = "M^intercal"
			local expected_ast = {
				type = "transpose",
				expression = base_node("M", "variable"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse X^{\\mathsf{T}} (tested as X^T for mock)", function()
			local input = "X^T"
			local expected_ast = {
				type = "transpose",
				expression = base_node("X", "variable"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse A^{T} as a transpose", function()
			local input = "A^{T}"
			local expected_ast = {
				type = "transpose",
				expression = base_node("A", "variable"),
			}
			local result = parse_input(input)
			assert.are.same(expected_ast, result)
		end)

		it("should parse VarName^T (multi-character variable)", function()
			local input = "VarName^T"
			local expected_ast = {
				type = "transpose",
				expression = base_node("VarName", "variable"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse (A+B)^T (grouped expression)", function()
			local input = "(A+B)^T"
			local expected_ast = {
				type = "transpose",
				expression = base_node("A+B", "group"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse M_1^T (subscripted base)", function()
			local input = "M_1^T"
			local expected_ast = {
				type = "transpose",
				expression = { type = "subscript", base = base_node("M", "variable"), subscript = base_node(1, "number") },
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse M^2^T (superscripted base, implies (M^2)^T )", function()
			local input = "M^2^T"
			local expected_ast = {
				type = "transpose",
				expression = { type = "superscript", base = base_node("M", "variable"), exponent = base_node(2, "number") },
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse \\mymatrix^{\\intercal} (custom matrix placeholder, tested as ^intercal)", function()
			local input = "\\mymatrix^intercal"
			local expected_ast = {
				type = "transpose",
				expression = matrix_node_placeholder("mymatrix"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse with spaces: A ^ T", function()
			local input = "A ^ T"
			local expected_ast = {
				type = "transpose",
				expression = base_node("A", "variable"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)

		it("should parse with spaces: M ^ intercal", function()
			local input = "M ^ intercal"
			local expected_ast = {
				type = "transpose",
				expression = base_node("M", "variable"),
			}
			assert.are.same(expected_ast, parse_input(input))
		end)
	end)

	describe("Invalid transpose notations or edge cases", function()
		it("should not parse A^TT (double T)", function()
			assert.is_nil(parse_input("A^TT"))
		end)

		it("should not parse A^ (incomplete)", function()
			assert.is_nil(parse_input("A^"))
		end)

		it("should not parse A^{\\intercal (incomplete)", function()
			assert.is_nil(parse_input("A^{\\intercal"))
		end)

		it("should not parse ^T A (operator before base)", function()
			assert.is_nil(parse_input("^T A"))
		end)

		it("should not parse A^t (lowercase t)", function()
			assert.is_nil(parse_input("A^t"))
		end)
	end)
end)
