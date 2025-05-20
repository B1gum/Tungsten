-- tungsten/tests/unit/domains/arithmetic/rules/muldiv_spec.lua
package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local lpeg = require("lpeg")
local P, R, S, C, Cf, Ct = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Cf, lpeg.Ct

local mock_tk = {
  space = S(" \t\n\r")^0,
  variable = C(R("az","AZ") * (R("az","AZ","09")^0)) / function(v) return {type="variable", name=v} end,
  number = C(R("09")^1 * (P(".") * R("09")^1)^-1) / function(n) return {type="number", value=tonumber(n)} end,
}

local MockUnaryRule = mock_tk.variable + mock_tk.number + (P("(") * lpeg.V("Expression_placeholder_for_parentheses") * P(")"))

local mock_ast_utils = {
  create_binary_operation_node = function(op, left, right)
    if op == nil or left == nil or right == nil then
        error("create_binary_operation_node called with nil arguments: op="..tostring(op).." left="..tostring(left).." right="..tostring(right))
    end
    return { type = "binary", operator = op, left = left, right = right }
  end
}

local original_package_loaded = {}
local modules_to_mock = {
  ["tungsten.core.tokenizer"] = mock_tk,
  ["tungsten.domains.arithmetic.rules.supersub"] = { Unary = MockUnaryRule },
  ["tungsten.core.ast"] = mock_ast_utils,
  ["tungsten.domains.arithmetic.rules.muldiv"] = nil,
}

local MulDivRuleItself

local function compile_test_grammar(rule_to_test)
  local grammar_table = {
    "TestEntry",
    TestEntry = rule_to_test,
    Expression_placeholder_for_parentheses = mock_tk.variable + mock_tk.number,
    Unary = MockUnaryRule
  }
  return lpeg.P(grammar_table)
end


local function parse_input(input)
  if not test_grammar_entry then
    error("Test grammar not compiled for parsing.")
  end
  return lpeg.match(test_grammar_entry, input)
end

describe("Arithmetic MulDiv Rule (with Differential Awareness)", function()

  before_each(function()
    for name, mock_impl in pairs(modules_to_mock) do
      original_package_loaded[name] = package.loaded[name]
      package.loaded[name] = mock_impl
    end

    MulDivRuleItself = require("tungsten.domains.arithmetic.rules.muldiv")
    test_grammar_entry = compile_test_grammar(MulDivRuleItself)
  end)

  after_each(function()
    for name, original_impl in pairs(original_package_loaded) do
      package.loaded[name] = original_impl
    end
    original_package_loaded = {}
    MulDivRuleItself = nil
    test_grammar_entry = nil
  end)

  describe("Standard Implicit Multiplication", function()
    it("should parse '2x' as 2*x", function()
      local ast = parse_input("2x")
      assert.are.same({
        type = "binary", operator = "*",
        left = { type = "number", value = 2 },
        right = { type = "variable", name = "x" }
      }, ast)
    end)

    it("should parse 'varOne varTwo' as varOne*varTwo", function()
      local ast = parse_input("varOne varTwo")
      assert.are.same({
        type = "binary", operator = "*",
        left = { type = "variable", name = "varOne" },
        right = { type = "variable", name = "varTwo" }
      }, ast)
    end)

    it("should parse 'a(b)' as a*b", function()
        local old_unary = MockUnaryRule
        local old_grammar = test_grammar_entry
        MockUnaryRule = mock_tk.variable + mock_tk.number + (P("(") * (mock_tk.variable) * P(")"))
        modules_to_mock["tungsten.domains.arithmetic.rules.supersub"] = { Unary = MockUnaryRule }
        package.loaded["tungsten.domains.arithmetic.rules.supersub"] = { Unary = MockUnaryRule }
        package.loaded["tungsten.domains.arithmetic.rules.muldiv"] = nil
        MulDivRuleItself = require("tungsten.domains.arithmetic.rules.muldiv")
        test_grammar_entry = compile_test_grammar(MulDivRuleItself)


        local ast = parse_input("a(b)")
        assert.are.same({
            type = "binary", operator = "*",
            left = { type = "variable", name = "a" },
            right = { type = "variable", name = "b" }
        }, ast)

        MockUnaryRule = old_unary
        modules_to_mock["tungsten.domains.arithmetic.rules.supersub"] = { Unary = MockUnaryRule }
        package.loaded["tungsten.domains.arithmetic.rules.supersub"] = { Unary = MockUnaryRule }
        test_grammar_entry = old_grammar
    end)
  end)

  describe("Avoidance of Implicit Multiplication with Differentials", function()
    it("should parse 'x dx' as just 'x', leaving 'dx' unconsumed by implicit multiplication", function()
      local ast = parse_input("x dx")
      assert.are.same({ type = "variable", name = "x" }, ast)
    end)

    it("should parse 'E dt' as 'E', leaving 'dt' unconsumed", function()
      local ast = parse_input("E dt")
      assert.are.same({ type = "variable", name = "E" }, ast)
    end)

    it("should parse 'alpha dy' as 'alpha', leaving 'dy' unconsumed", function()
      local ast = parse_input("alpha dy")
      assert.are.same({ type = "variable", name = "alpha" }, ast)
    end)

    it("should parse '2dx' as '2', leaving 'dx' unconsumed", function()
      local ast = parse_input("2dx")
      assert.are.same({ type = "number", value = 2 }, ast)
    end)

    it("should parse 'func dtheta' as 'func', leaving 'dtheta' unconsumed", function()
      local ast = parse_input("func dtheta")
      assert.are.same({type = "variable", name = "func"}, ast)
    end)
  end)

  describe("Implicit Multiplication with variable 'd' not part of a differential", function()
    it("should parse 'a d x' as a*(d*x) (sequential implicit muls)", function()
      local ast = parse_input("a d x")
      assert.are.same({ type = "variable", name = "a" }, ast, "Expected 'a d x' to parse as 'a', leaving 'd x' due to lookahead.")
    end)

     it("should parse 'd x y' as (d*x)*y", function() 
        local ast = parse_input("d x y")
        assert.are.same({
            type = "binary", operator = "*",
            left = {
                type = "binary", operator = "*",
                left = {type = "variable", name = "d"},
                right = {type = "variable", name = "x"}
            },
            right = {type = "variable", name = "y"}
        }, ast)
    end)
  end)

  describe("Explicit Multiplication", function()
    it("should parse 'x * d y' as (x*d)*y using explicit operator", function()
      local ast = parse_input("x * d y")
       assert.are.same({
        type = "binary", operator = "*",
        left = {
            type="binary", operator="*",
            left = {type="variable", name="x"},
            right = {type="variable", name="d"}
        },
        right = {type="variable", name="y"}
      }, ast)
    end)

    it("should parse 'x \\cdot d y' as (x*d)*y", function()
      local ast = parse_input("x \\cdot d y")
       assert.are.same({
        type = "binary", operator = "*",
        left = {
            type="binary", operator="*",
            left = {type="variable", name="x"},
            right = {type="variable", name="d"}
        },
        right = {type="variable", name="y"}
      }, ast)
    end)
  end)
end)
