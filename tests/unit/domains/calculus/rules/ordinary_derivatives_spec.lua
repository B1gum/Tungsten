-- tests/unit/domains/calculus/rules/ordinary_derivatives_spec.lua

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local lpeg = require("lpeg")
local P, V, C, R, S = lpeg.P, lpeg.V, lpeg.C, lpeg.R, lpeg.S

local OrdinaryDerivativeRule

local mock_tokenizer_module
local mock_ast_module
local modules_to_reset = {
  "tungsten.domains.calculus.rules.ordinary_derivatives",
  "tungsten.core.tokenizer",
  "tungsten.core.ast",
}

local test_grammar_table_definition
local compiled_test_grammar

local function placeholder_node(node_type, val_str, original_type_if_known)
  return { type = node_type, value_str = val_str, original_type = original_type_if_known or node_type }
end


describe("Calculus Ordinary Derivative Rule: tungsten.domains.calculus.rules.ordinary_derivatives", function()

  before_each(function()
    for _, name in ipairs(modules_to_reset) do
      package.loaded[name] = nil
    end

    mock_tokenizer_module = {
      space = S(" \t\n\r")^0,
      lbrace = P("{"),
      rbrace = P("}"),
      variable = C(R("az", "AZ") * (R("az", "AZ", "09")^0)) / function(name_str)
        return { type = "variable", name = name_str }
      end,
      number = C(R("09")^1 * (P(".") * R("09")^1)^-1) / function(num_str)
        return { type = "number", value = tonumber(num_str) }
      end,
    }
    package.loaded["tungsten.core.tokenizer"] = mock_tokenizer_module

    mock_ast_module = {
      node = function(type, fields)
        fields = fields or {}
        fields.type = type
        return fields
      end
    }
    package.loaded["tungsten.core.ast"] = mock_ast_module

    OrdinaryDerivativeRule = require("tungsten.domains.calculus.rules.ordinary_derivatives")

    test_grammar_table_definition = {
      "TestEntryPoint",

      TestEntryPoint = OrdinaryDerivativeRule * -P(1),

      AtomBase = (
        mock_tokenizer_module.number +
        mock_tokenizer_module.variable
      ),

      Expression = (
        P("{x^2+y^2}") / function() return placeholder_node("placeholder_expr", "x^2+y^2_in_braces", "binary_op") end +
        P("f(x)") / function() return placeholder_node("placeholder_expr", "f(x)", "function_call") end +
        P("(a+b)") / function() return placeholder_node("placeholder_expr", "a+b_in_parens", "binary_op") end +
        P("longVar") / function() return { type = "variable", name = "longVar"} end +
        V("AtomBase")
      ),
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

  describe("First-order derivatives", function()
    it("should parse \\frac{d}{dx} x (variable as expression)", function()
      local input = "\\frac{d}{dx} x"
      local expected_ast = {
        type = "ordinary_derivative",
        expression = { type = "variable", name = "x" },
        variable = { type = "variable", name = "x" },
        order = { type = "number", value = 1 }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\frac{\\mathrm{d}}{\\mathrm{d}t} {x^2+y^2} (braced complex expression)", function()
      local input = "\\frac{\\mathrm{d}}{\\mathrm{d}t} {x^2+y^2}"
      local expected_ast = {
        type = "ordinary_derivative",
        expression = placeholder_node("placeholder_expr", "x^2+y^2_in_braces", "binary_op"),
        variable = { type = "variable", name = "t" },
        order = { type = "number", value = 1 }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\frac{d}{dlongVar} (a+b) (multi-character variable for differentiation)", function()
      local input = "\\frac{d}{dlongVar} (a+b)"
      local expected_ast = {
        type = "ordinary_derivative",
        expression = placeholder_node("placeholder_expr", "a+b_in_parens", "binary_op"),
        variable = { type = "variable", name = "longVar" },
        order = { type = "number", value = 1 }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\frac{d}{dx} f(x) (unbraced function call as expression)", function()
        local input = "\\frac{d}{dx} f(x)"
        local expected_ast = {
            type = "ordinary_derivative",
            expression = placeholder_node("placeholder_expr", "f(x)", "function_call"),
            variable = { type = "variable", name = "x"},
            order = { type = "number", value = 1}
        }
        assert.are.same(expected_ast, parse_input(input))
    end)
  end)

  describe("Higher-order derivatives", function()
    it("should parse \\frac{d^2}{dx^2} x (numeric order)", function()
      local input = "\\frac{d^2}{dx^2} x"
      local expected_ast = {
        type = "ordinary_derivative",
        expression = { type = "variable", name = "x" },
        variable = { type = "variable", name = "x" },
        order = { type = "number", value = 2 }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\frac{\\mathrm{d}^n}{\\mathrm{d}t^n} {x^2+y^2} (variable order 'n')", function()
      local input = "\\frac{\\mathrm{d}^n}{\\mathrm{d}t^n} {x^2+y^2}"
      local expected_ast = {
        type = "ordinary_derivative",
        expression = placeholder_node("placeholder_expr", "x^2+y^2_in_braces", "binary_op"),
        variable = { type = "variable", name = "t" },
        order = { type = "variable", name = "n" }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\frac{d^3}{dAlpha^3} f(x) (multi-char variable for differentiation, numeric order)", function()
        local input = "\\frac{d^3}{dAlpha^3} f(x)"
        local expected_ast = {
            type = "ordinary_derivative",
            expression = placeholder_node("placeholder_expr", "f(x)", "function_call"),
            variable = { type = "variable", name = "Alpha"},
            order = { type = "number", value = 3}
        }
        assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\frac{d^2}{dx^n} x (order in denominator differs from numerator, numerator's order is used)", function()
      local input = "\\frac{d^2}{dx^n} x"
       local expected_ast = {
        type = "ordinary_derivative",
        expression = { type = "variable", name = "x" },
        variable = { type = "variable", name = "x" },
        order = { type = "number", value = 2 }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)
  end)

  describe("Spacing and d/\\mathrm{d} variations", function()
    it("should handle extra spaces within \\frac definition: \\frac { d } { d x } y", function()
      local input = "\\frac { d } { d x } y"
      local expected_ast = {
        type = "ordinary_derivative",
        expression = { type = "variable", name = "y" },
        variable = { type = "variable", name = "x" },
        order = { type = "number", value = 1 }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should handle no space before the differentiated expression: \\frac{d}{dx}y", function()
      local input = "\\frac{d}{dx}y"
      local expected_ast = {
        type = "ordinary_derivative",
        expression = { type = "variable", name = "y" },
        variable = { type = "variable", name = "x" },
        order = { type = "number", value = 1 }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should handle mixed 'd' and '\\mathrm{d}' forms: \\frac{\\mathrm{d}^2}{dx^2} x", function()
      local input = "\\frac{\\mathrm{d}^2}{dx^2} x"
       local expected_ast = {
        type = "ordinary_derivative",
        expression = { type = "variable", name = "x" },
        variable = { type = "variable", name = "x" },
        order = { type = "number", value = 2 }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

     it("should handle mixed 'd' and '\\mathrm{d}' other way: \\frac{d^2}{\\mathrm{d}x^2} x", function()
      local input = "\\frac{d^2}{\\mathrm{d}x^2} x"
       local expected_ast = {
        type = "ordinary_derivative",
        expression = { type = "variable", name = "x" },
        variable = { type = "variable", name = "x" },
        order = { type = "number", value = 2 }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)
  end)

  describe("Invalid syntax (should not parse to ordinary_derivative)", function()
    it("should not parse incomplete fraction structure: \\frac{d}{dx", function()
      assert.is_nil(parse_input("\\frac{d}{dx"))
    end)

    it("should not parse if variable is missing: \\frac{d}{d} x", function()
      assert.is_nil(parse_input("\\frac{d}{d} x"))
    end)

    it("should not parse if expression part is missing entirely: \\frac{d}{dx}", function()
        assert.is_nil(parse_input("\\frac{d}{dx}"))
        assert.is_nil(parse_input("\\frac{d^2}{dx^2}"))
    end)

    it("should not parse incomplete order specification: \\frac{d^}{dx} x", function()
      assert.is_nil(parse_input("\\frac{d^}{dx} x"))
    end)

    it("should not parse if higher-order numerator with first-order denominator structure: \\frac{d^2}{dx} x", function()
      assert.is_nil(parse_input("\\frac{d^2}{dx} x"))
    end)

    it("should not parse if first-order numerator with higher-order denominator structure: \\frac{d}{dx^2} x", function()
      assert.is_nil(parse_input("\\frac{d}{dx^2} x"))
    end)

    it("should not parse incorrect LaTeX command like \\diff: \\diff{d}{x} x", function()
      assert.is_nil(parse_input("\\diff{d}{x} x"))
    end)

  end)
end)
