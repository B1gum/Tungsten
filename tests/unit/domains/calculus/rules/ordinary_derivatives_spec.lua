-- tungsten/tests/unit/domains/calculus/rules/ordinary_derivatives_spec.lua
-- Unit tests for the unified ordinary derivative parsing rule.

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local lpeg = require "lpeg"
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

describe("Calculus Unified Ordinary Derivative Rule", function()

  before_each(function()
    for _, name in ipairs(modules_to_reset) do
      package.loaded[name] = nil
    end

    mock_tokenizer_module = {
      space = S(" \t\n\r")^0,
      lbrace = P("{"),
      rbrace = P("}"),
      lparen = P("("),
      rparen = P(")"),
      variable = C(R("az", "AZ") * (R("az", "AZ", "09")^0)) / function(name_str)
        return { type = "variable", name = name_str }
      end,
      number = C(R("09")^1 * (P(".") * R("09")^1)^-1) / function(num_str)
        return { type = "number", value = tonumber(num_str) }
      end,
    }
    package.loaded["tungsten.core.tokenizer"] = mock_tokenizer_module

    mock_ast_module = {
      create_ordinary_derivative_node = function(expression, variable, order)
        return {
          type = "ordinary_derivative",
          expression = expression,
          variable = variable,
          order = order or { type = "number", value = 1 }
        }
      end,
       create_function_call_node = function(name_node, args_table)
        return { type = "function_call", name_node = name_node, args = args_table }
       end,
    }
    package.loaded["tungsten.core.ast"] = mock_ast_module


    OrdinaryDerivativeRule = require("tungsten.domains.calculus.rules.ordinary_derivatives")

    local function_call_rule = (mock_tokenizer_module.variable * mock_tokenizer_module.lparen * mock_tokenizer_module.variable * mock_tokenizer_module.rparen) /
        function(name, arg) return mock_ast_module.create_function_call_node(name, {arg}) end

    test_grammar_table_definition = {
      "TestEntryPoint",
      TestEntryPoint = OrdinaryDerivativeRule * -P(1),
      AtomBase = function_call_rule + mock_tokenizer_module.variable + mock_tokenizer_module.number + (P"\\theta" / function() return {type="variable", name="theta"} end),
      Expression = V("AtomBase")
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

  describe("Leibniz Notation (\\frac)", function()
    it("should parse first-order: \\frac{d}{dx} f(x)", function()
      local input = "\\frac{d}{dx} f(x)"
      local expected = {
        type = "ordinary_derivative",
        expression = { type = "function_call", name_node = { type = "variable", name = "f" }, args = {{ type = "variable", name = "x" }} },
        variable = { type = "variable", name = "x" },
        order = { type = "number", value = 1 }
      }
      assert.are.same(expected, parse_input(input))
    end)

    it("should parse second-order: \\frac{d^2}{dt^2} y", function()
        local input = "\\frac{d^2}{dt^2} y"
        local expected = {
            type = "ordinary_derivative",
            expression = { type = "variable", name = "y" },
            variable = { type = "variable", name = "t" },
            order = { type = "number", value = 2 }
        }
        assert.are.same(expected, parse_input(input))
    end)

    it("should parse n-th order: \\frac{d^n}{dx^n} f(x)", function()
        local input = "\\frac{d^n}{dx^n} f(x)"
        local expected = {
            type = "ordinary_derivative",
            expression = { type = "function_call", name_node = { type = "variable", name = "f" }, args = {{ type = "variable", name = "x" }} },
            variable = { type = "variable", name = "x" },
            order = { type = "variable", name = "n" }
        }
        assert.are.same(expected, parse_input(input))
    end)
  end)

  describe("Lagrange Notation (')", function()
    it("should parse first-order: y'", function()
      local input = "y'"
      local expected = {
        type = "ordinary_derivative",
        expression = { type = "variable", name = "y" },
        variable = { type = "variable", name = "x" },
        order = { type = "number", value = 1 }
      }
      assert.are.same(expected, parse_input(input))
    end)

    it("should parse second-order: f''(x)", function()
      local input = "f''(x)"
      local expected = {
        type = "ordinary_derivative",
        expression = { type = "function_call", name_node = { type = "variable", name = "f" }, args = {{ type = "variable", name = "x" }} },
        variable = { type = "variable", name = "x" },
        order = { type = "number", value = 2 }
      }
      assert.are.same(expected, parse_input(input))
    end)

    it("should parse third-order: y'''", function()
      local input = "y'''"
      local expected = {
        type = "ordinary_derivative",
        expression = { type = "variable", name = "y" },
        variable = { type = "variable", name = "x" },
        order = { type = "number", value = 3 }
      }
      assert.are.same(expected, parse_input(input))
    end)

    it("should not parse with spaces: y '", function()
        assert.is_nil(parse_input("y '"))
    end)
  end)

  describe("Newton Notation (\\dot)", function()
      it("should parse first-order: \\dot{x}", function()
        local input = "\\dot{x}"
        local expected = {
            type = "ordinary_derivative",
            expression = { type = "variable", name = "x" },
            variable = { type = "variable", name = "t" },
            order = { type = "number", value = 1 }
        }
        assert.are.same(expected, parse_input(input))
      end)

      it("should parse second-order: \\ddot{\\theta}", function()
        local input = "\\ddot{\\theta}"
        local expected = {
            type = "ordinary_derivative",
            expression = { type = "variable", name = "theta" },
            variable = { type = "variable", name = "t" },
            order = { type = "number", value = 2 }
        }
        assert.are.same(expected, parse_input(input))
      end)

      it("should parse with braces: \\ddot{\\theta}", function()
          local input = "\\ddot{\\theta}"
          local expected = {
            type = "ordinary_derivative",
            expression = { type = "variable", name = "theta" },
            variable = { type = "variable", name = "t" },
            order = { type = "number", value = 2 }
          }
          assert.are.same(expected, parse_input(input))
      end)

      it("should not parse with space: \\dot x", function()
          assert.is_nil(parse_input("\\dot x"))
      end)
  end)

  describe("Invalid Syntax", function()
    it("should not parse incomplete leibniz: \\frac{d}{dx}", function()
        assert.is_nil(parse_input("\\frac{d}{dx}"))
    end)
    it("should not parse incomplete lagrange: y", function()
        assert.is_nil(parse_input("y"))
    end)
    it("should not parse incomplete newton: \\dot", function()
        assert.is_nil(parse_input("\\dot"))
    end)
    it("should not parse mixed notations together: y' \\dot{x}", function()
        assert.is_nil(parse_input("y' \\dot{x}"))
    end)
  end)
end)
