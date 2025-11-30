local lpeg = require("lpeglabel")
local P, R, S, V, Ct = lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.Ct

local modules_to_reset = {
	"tungsten.core.tokenizer",
	"tungsten.core.ast",
	"tungsten.domains.arithmetic.rules.fraction",
	"tungsten.domains.arithmetic.rules.sqrt",
	"tungsten.domains.arithmetic.rules.function_call",
	"tungsten.domains.arithmetic.rules.trig_functions",
	"tungsten.domains.arithmetic.rules.log_functions",
	"tungsten.domains.arithmetic.rules.addsub",
	"tungsten.domains.arithmetic.rules.relation",
}

local mock_tokenizer_module
local mock_ast_module

local fraction_rule
local sqrt_rule
local function_call_rule
local trig_functions
local log_functions
local addsub_rule
local relation_rules

local function reset_modules()
	for _, name in ipairs(modules_to_reset) do
		package.loaded[name] = nil
	end
end

local function compile_grammar(grammar_table)
	return lpeg.P(grammar_table)
end

describe("Arithmetic foundational rule coverage", function()
	before_each(function()
		reset_modules()

		mock_tokenizer_module = {
			space = S(" \t\n\r") ^ 0,
			lparen = P("("),
			rparen = P(")"),
			lbrace = P("{"),
			rbrace = P("}"),
			lbrack = P("["),
			rbrack = P("]"),
			equals_op = P("=") / function(eq)
				return eq
			end,
			variable = P("\\") ^ -1 * (R("az", "AZ") * (R("az", "AZ", "09") ^ 0)) / function(s)
				return { type = "variable", name = s }
			end,
			number = (P("-") ^ -1 * R("09") ^ 1) / function(s)
				return { type = "number", value = tonumber(s) }
			end,
		}
		package.loaded["tungsten.core.tokenizer"] = mock_tokenizer_module

		mock_ast_module = {
			create_fraction_node = function(num, den)
				return { type = "fraction", numerator = num, denominator = den }
			end,
			create_sqrt_node = function(rad, idx)
				return { type = "sqrt", radicand = rad, index = idx }
			end,
			create_function_call_node = function(name_node, args)
				return { type = "function_call", name = name_node, args = args }
			end,
			create_variable_node = function(name)
				return { type = "variable", name = name }
			end,
			create_binary_operation_node = function(op, left, right)
				return { type = "binary", operator = op, left = left, right = right }
			end,
			create_inequality_node = function(lhs, op, rhs)
				return { type = "inequality", op = op, lhs = lhs, rhs = rhs }
			end,
			create_equality_node = function(lhs, rhs)
				return { type = "equality", lhs = lhs, rhs = rhs }
			end,
		}
		package.loaded["tungsten.core.ast"] = mock_ast_module

		fraction_rule = require("tungsten.domains.arithmetic.rules.fraction")
		sqrt_rule = require("tungsten.domains.arithmetic.rules.sqrt")
		function_call_rule = require("tungsten.domains.arithmetic.rules.function_call")
		trig_functions = require("tungsten.domains.arithmetic.rules.trig_functions")
		log_functions = require("tungsten.domains.arithmetic.rules.log_functions")
		addsub_rule = require("tungsten.domains.arithmetic.rules.addsub")
		relation_rules = require("tungsten.domains.arithmetic.rules.relation")
	end)

	after_each(function()
		reset_modules()
	end)

	describe("Fraction and square root parsing", function()
		it("parses \\frac with number and variable", function()
			local grammar = {
				"Entry",
				Entry = fraction_rule * -P(1),
				Expression = mock_tokenizer_module.number + mock_tokenizer_module.variable,
			}

			local result = lpeg.match(compile_grammar(grammar), "\\frac{3}{x}")

			assert.are.same({
				type = "fraction",
				numerator = { type = "number", value = 3 },
				denominator = { type = "variable", name = "x" },
			}, result)
		end)

		it("parses \\sqrt with and without index", function()
			local grammar = {
				"Entry",
				Entry = sqrt_rule * -P(1),
				Expression = mock_tokenizer_module.number + mock_tokenizer_module.variable,
			}
			local compiled = compile_grammar(grammar)

			local no_index = lpeg.match(compiled, "\\sqrt{9}")
			assert.are.same({
				type = "sqrt",
				radicand = { type = "number", value = 9 },
				index = nil,
			}, no_index)

			local with_index = lpeg.match(compiled, "\\sqrt[3]{y}")
			assert.are.same({
				type = "sqrt",
				radicand = { type = "variable", name = "y" },
				index = { type = "number", value = 3 },
			}, with_index)
		end)
	end)

	describe("Function call arguments", function()
		it("captures multiple arguments", function()
			local grammar = {
				"Entry",
				Entry = function_call_rule * -P(1),
				Expression = mock_tokenizer_module.number + mock_tokenizer_module.variable,
			}
			local result = lpeg.match(compile_grammar(grammar), "f(1, x, 3)")

			assert.are.same({
				type = "function_call",
				name = { type = "variable", name = "f" },
				args = {
					{ type = "number", value = 1 },
					{ type = "variable", name = "x" },
					{ type = "number", value = 3 },
				},
			}, result)
		end)
	end)

	describe("Logarithm and trigonometric rules", function()
		it("supports ln with parentheses and log with braces", function()
			local grammar_ln = {
				"Entry",
				Entry = log_functions.LnRule * -P(1),
				Expression = mock_tokenizer_module.number + mock_tokenizer_module.variable,
				Unary = V("Expression"),
			}
			local ln_ast = lpeg.match(compile_grammar(grammar_ln), "\\ln(5)")
			assert.are.same({
				type = "function_call",
				name = { type = "variable", name = "ln" },
				args = { { type = "number", value = 5 } },
			}, ln_ast)

			local grammar_log = {
				"Entry",
				Entry = log_functions.LogRule * -P(1),
				Expression = mock_tokenizer_module.variable,
				Unary = V("Expression"),
			}
			local log_ast = lpeg.match(compile_grammar(grammar_log), "\\log{z}")
			assert.are.same({
				type = "function_call",
				name = { type = "variable", name = "log" },
				args = { { type = "variable", name = "z" } },
			}, log_ast)
		end)

		it("allows trig functions to consume unary expressions", function()
			local grammar = {
				"Entry",
				Entry = trig_functions.SinRule * -P(1),
				Expression = mock_tokenizer_module.variable,
				Unary = V("Expression"),
			}
			local sin_ast = lpeg.match(compile_grammar(grammar), "\\sin x")
			assert.are.same({
				type = "function_call",
				name = { type = "variable", name = "sin" },
				args = { { type = "variable", name = "x" } },
			}, sin_ast)

			grammar.Entry = trig_functions.CosRule * -P(1)
			local cos_ast = lpeg.match(compile_grammar(grammar), "\\cos{y}")
			assert.are.same({
				type = "function_call",
				name = { type = "variable", name = "cos" },
				args = { { type = "variable", name = "y" } },
			}, cos_ast)
		end)
	end)

	describe("AddSub chaining", function()
		it("builds nested binary operations", function()
			local grammar = {
				"Entry",
				Entry = addsub_rule * -P(1),
				Expression = V("AddSub"),
				AddSub = addsub_rule,
				MulDiv = V("Unary"),
				Unary = V("Atom"),
				Atom = mock_tokenizer_module.number + mock_tokenizer_module.variable,
			}

			local ast = lpeg.match(compile_grammar(grammar), "1+2-3")

			assert.are.same({
				type = "binary",
				operator = "-",
				left = {
					type = "binary",
					operator = "+",
					left = { type = "number", value = 1 },
					right = { type = "number", value = 2 },
				},
				right = { type = "number", value = 3 },
			}, ast)
		end)
	end)

	describe("Equality and inequality mapping", function()
		it("maps grouped inequality symbols", function()
			local grammar = {
				"Entry",
				Entry = relation_rules.Inequality * -P(1),
				ExpressionContent = mock_tokenizer_module.variable,
			}

			local mapped = lpeg.match(compile_grammar(grammar), "a <= b")
			assert.are.same({
				type = "inequality",
				op = "≤",
				lhs = { type = "variable", name = "a" },
				rhs = { type = "variable", name = "b" },
			}, mapped)

			local unmapped = lpeg.match(compile_grammar(grammar), "c < d")
			assert.are.same({
				type = "inequality",
				op = "<",
				lhs = { type = "variable", name = "c" },
				rhs = { type = "variable", name = "d" },
			}, unmapped)
		end)

		it("captures equality expressions", function()
			local grammar = {
				"Entry",
				Entry = relation_rules.Equality * -P(1),
				ExpressionContent = mock_tokenizer_module.number + mock_tokenizer_module.variable,
			}

			local equality_ast = lpeg.match(compile_grammar(grammar), "4 = x")
			assert.are.same({
				type = "equality",
				lhs = { type = "number", value = 4 },
				rhs = { type = "variable", name = "x" },
			}, equality_ast)
		end)
	end)
end)
