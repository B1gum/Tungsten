-- tungsten/tests/unit/domains/arithmetic/rules/solve_system_rule_spec.lua
-- Unit tests for the solve_system_rule parsing rule.
---------------------------------------------------------------------

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local lpeg = require "lpeg"
local P, V, C, R, S, Ct = lpeg.P, lpeg.V, lpeg.C, lpeg.R, lpeg.S, lpeg.Ct

local SolveSystemRule

local mock_tokenizer_module
local mock_ast_module
local modules_to_reset = {
  "tungsten.domains.arithmetic.rules.solve_system_rule",
  "tungsten.core.tokenizer",
  "tungsten.core.ast",
}

local test_grammar_table_definition
local compiled_test_grammar

local function equation_placeholder_node(val_str)
  return { type = "equation_placeholder", value = val_str }
end

describe("Arithmetic Solve System Rule: tungsten.domains.arithmetic.rules.solve_system_rule", function()

  before_each(function()
    for _, name in ipairs(modules_to_reset) do
      package.loaded[name] = nil
    end

    mock_tokenizer_module = {
      space = S(" \t\n\r")^0,
      equals_op = P("=") / function() return { type = "equals_op_token"} end,
      variable = C(R("az","AZ") * (R("az","AZ","09")^0)) / function(s) return {type="variable", name=s} end,
      number = C(R("09")^1) / function(s) return {type="number", value=tonumber(s)} end,
    }
    package.loaded["tungsten.core.tokenizer"] = mock_tokenizer_module

    mock_ast_module = {
      create_binary_operation_node = function(op, left, right)
        return { type = "binary", operator = op, left = left, right = right}
      end
    }
    package.loaded["tungsten.core.ast"] = mock_ast_module

    SolveSystemRule = require("tungsten.domains.arithmetic.rules.solve_system_rule")

    local simplified_equation_rule = Ct(
        mock_tokenizer_module.variable * mock_tokenizer_module.space * mock_tokenizer_module.equals_op * mock_tokenizer_module.space * mock_tokenizer_module.number
    ) / function (captures)
        return equation_placeholder_node(captures[1].name .. "=" .. captures[3].value)
    end


    test_grammar_table_definition = {
      "TestEntryPoint",
      TestEntryPoint = SolveSystemRule * -P(1),
      EquationRule = simplified_equation_rule,
      Expression = mock_tokenizer_module.variable + mock_tokenizer_module.number
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

  describe("Valid System of Equations Parsing", function()
    it("should parse a single equation: x=1", function()
      local input = "x=1"
      local expected_ast = {
        type = "solve_system_equations_capture",
        equations = {
          equation_placeholder_node("x=1")
        }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse two equations separated by \\\\: x=1 \\\\ y=2", function()
      local input = "x=1 \\\\ y=2"
      local expected_ast = {
        type = "solve_system_equations_capture",
        equations = {
          equation_placeholder_node("x=1"),
          equation_placeholder_node("y=2")
        }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse two equations separated by ;: x=1 ; y=2", function()
      local input = "x=1 ; y=2"
      local expected_ast = {
        type = "solve_system_equations_capture",
        equations = {
          equation_placeholder_node("x=1"),
          equation_placeholder_node("y=2")
        }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse multiple equations with mixed separators: a=1 \\\\ b=2 ; c=3", function()
      local input = "a=1 \\\\ b=2 ; c=3"
      local expected_ast = {
        type = "solve_system_equations_capture",
        equations = {
          equation_placeholder_node("a=1"),
          equation_placeholder_node("b=2"),
          equation_placeholder_node("c=3")
        }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should handle spaces around separators: x=1  \\\\  y=2   ;   z=3", function()
      local input = "x=1  \\\\  y=2   ;   z=3"
      local expected_ast = {
        type = "solve_system_equations_capture",
        equations = {
          equation_placeholder_node("x=1"),
          equation_placeholder_node("y=2"),
          equation_placeholder_node("z=3")
        }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)
  end)

  describe("Invalid System Structures", function()
    it("should not parse if equation is incomplete: x=", function()
      assert.is_nil(parse_input("x="))
    end)

    it("should not parse system ending with a separator: x=1 \\\\", function()
      assert.is_nil(parse_input("x=1 \\\\"))
    end)

    it("should not parse system starting with a separator: \\\\ x=1", function()
      assert.is_nil(parse_input("\\\\ x=1"))
    end)

    it("should not parse multiple separators together: x=1 \\\\ ; y=2", function()
      assert.is_nil(parse_input("x=1 \\\\ ; y=2"))
    end)

    it("should not parse empty input", function()
      assert.is_nil(parse_input(""))
    end)
  end)
end)
