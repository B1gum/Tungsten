-- tests/unit/domains/linear_algebra/rules/cross_product_spec.lua
-- Unit tests for the cross product parsing rule.
-----------------------------------------------------------------------

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local lpeg = require "lpeglabel"
local P, C, R, S = lpeg.P, lpeg.C, lpeg.R, lpeg.S

local CrossProductRule

local mock_tokenizer_module
local mock_ast_module
local modules_to_reset = {
  "tungsten.domains.linear_algebra.rules.cross_product",
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

describe("Linear Algebra Cross Product Rule: tungsten.domains.linear_algebra.rules.cross_product", function()

  before_each(function()
    for _, name in ipairs(modules_to_reset) do
      package.loaded[name] = nil
    end

    mock_tokenizer_module = {
      space = S(" \t\n\r")^0,
      times_command = P("\\times") / function() return { type = "times_command_token" } end,
      variable = C(R("az","AZ") * (R("az","AZ","09")^0)) / function(s) return variable_node(s) end,
      vec_command = P("\\vec{") * C(R("az","AZ")^1) * P("}") / function(s) return vector_node(s) end,
    }
    package.loaded["tungsten.core.tokenizer"] = mock_tokenizer_module

    mock_ast_module = {
      create_cross_product_node = function(left_vector_ast, right_vector_ast)
        return {
          type = "cross_product",
          left = left_vector_ast,
          right = right_vector_ast
        }
      end
    }
    package.loaded["tungsten.core.ast"] = mock_ast_module

    CrossProductRule = require("tungsten.domains.linear_algebra.rules.cross_product")

    test_grammar_table_definition = {
      "TestEntryPoint",
      TestEntryPoint = CrossProductRule * -P(1),
      Expression = mock_tokenizer_module.vec_command + mock_tokenizer_module.variable
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

  describe("Valid cross product notations", function()
    it("should parse \\vec{a} \\times \\vec{b}", function()
      local input = "\\vec{a} \\times \\vec{b}"
      local expected_ast = {
        type = "cross_product",
        left = vector_node("a"),
        right = vector_node("b")
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse x \\times y (simple variables)", function()
      local input = "x \\times y"
      local expected_ast = {
        type = "cross_product",
        left = variable_node("x"),
        right = variable_node("y")
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse with varied spacing: \\vec{v1}   \\times   \\vec{v2}", function()
      local original_vec_command_mock = mock_tokenizer_module.vec_command
      mock_tokenizer_module.vec_command = P("\\vec{") * C(R("az","AZ","09")^1) * P("}") / function(s) return vector_node(s) end
      compiled_test_grammar = lpeg.P({
         "TestEntryPoint",
        TestEntryPoint = CrossProductRule * -P(1),
        Expression = mock_tokenizer_module.vec_command + mock_tokenizer_module.variable
      })


      local input = "\\vec{v1}   \\times   \\vec{v2}"
      local expected_ast = {
        type = "cross_product",
        left = vector_node("v1"),
        right = vector_node("v2")
      }
      assert.are.same(expected_ast, parse_input(input))
      mock_tokenizer_module.vec_command = original_vec_command_mock
    end)

    it("should parse without spaces: a\\times b", function()
      local input = "a\\times b"
       local expected_ast = {
        type = "cross_product",
        left = variable_node("a"),
        right = variable_node("b")
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse vectorOne \\times vectorTwo (multi-character variables)", function()
      local input = "vectorOne \\times vectorTwo"
      local expected_ast = {
        type = "cross_product",
        left = variable_node("vectorOne"),
        right = variable_node("vectorTwo")
      }
      assert.are.same(expected_ast, parse_input(input))
    end)
  end)

  describe("Invalid cross product notations", function()
    it("should not parse if \\times is missing: \\vec{a} \\vec{b}", function()
      assert.is_nil(parse_input("\\vec{a} \\vec{b}"))
    end)

    it("should not parse if left expression is missing: \\times \\vec{b}", function()
      assert.is_nil(parse_input("\\times \\vec{b}"))
    end)

    it("should not parse if right expression is missing: \\vec{a} \\times", function()
      assert.is_nil(parse_input("\\vec{a} \\times"))
    end)

    it("should not parse with incorrect command: \\vec{a} \\cdot \\vec{b}", function()
      assert.is_nil(parse_input("\\vec{a} \\cdot \\vec{b}"))
    end)

    it("should not parse only \\times", function()
      assert.is_nil(parse_input("\\times"))
    end)
  end)
end)
