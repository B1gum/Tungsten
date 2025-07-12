-- tests/unit/domains/linear_algebra/rules/norm_spec.lua
-- Unit tests for the norm parsing rule.
-----------------------------------------------------------------------

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local lpeg = require "lpeglabel"
local P, C, R, S = lpeg.P, lpeg.C, lpeg.R, lpeg.S

local NormRule

local mock_tokenizer_module
local mock_ast_module
local modules_to_reset = {
  "tungsten.domains.linear_algebra.rules.norm",
  "tungsten.core.tokenizer",
  "tungsten.core.ast",
}

local test_grammar_table_definition
local compiled_test_grammar

local function placeholder_expr_node(val_str, type_str_override)
  local node_type = type_str_override or "expression_placeholder"
  if tonumber(val_str) then
    node_type = type_str_override or "number"
    return { type = node_type, value = tonumber(val_str) }
  elseif val_str == "F" then
     return { type = "variable", name = "F" }
  end
  return { type = node_type, value = val_str }
end


describe("Linear Algebra Norm Rule: tungsten.domains.linear_algebra.rules.norm", function()

  before_each(function()
    for _, name in ipairs(modules_to_reset) do
      package.loaded[name] = nil
    end

    mock_tokenizer_module = {
      space = S(" \t\n\r")^0,
      double_pipe_norm = P("||") / function() return { type = "double_pipe_norm_token" } end,
      norm_delimiter_cmd = P("\\|") / function() return { type = "norm_delimiter_cmd_token" } end,
      lbrace = P("{"),
      rbrace = P("}"),
      variable = C(R("AZ","az") * (R("AZ","az","09")^0)) / function(s) return placeholder_expr_node(s, "variable") end,
      number = C(R("09")^1) / function(s) return placeholder_expr_node(s, "number") end,
    }
    package.loaded["tungsten.core.tokenizer"] = mock_tokenizer_module

    mock_ast_module = {
      create_norm_node = function(expression_ast, p_value_ast)
        return {
          type = "norm",
          expression = expression_ast,
          p_value = p_value_ast
        }
      end
    }
    package.loaded["tungsten.core.ast"] = mock_ast_module

    NormRule = require("tungsten.domains.linear_algebra.rules.norm")

    test_grammar_table_definition = {
      "TestEntryPoint",
      TestEntryPoint = NormRule * -P(1),
      Expression = mock_tokenizer_module.variable + mock_tokenizer_module.number,
      AtomBase = mock_tokenizer_module.variable + mock_tokenizer_module.number
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

  describe("Valid norm notations using ||...||", function()
    it("should parse ||A|| (no subscript)", function()
      local input = "||A||"
      local expected_ast = {
        type = "norm",
        expression = placeholder_expr_node("A", "variable"),
        p_value = nil
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse ||v||_2 (numeric subscript)", function()
      local input = "||v||_2"
      local expected_ast = {
        type = "norm",
        expression = placeholder_expr_node("v", "variable"),
        p_value = placeholder_expr_node("2", "number")
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse ||M||_F (single letter variable subscript)", function()
      local input = "||M||_F"
      local expected_ast = {
        type = "norm",
        expression = placeholder_expr_node("M", "variable"),
        p_value = { type = "variable", name = "F" }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse ||X||_{inf} (braced variable subscript)", function()
      local input = "||X||_{inf}"
      local expected_ast = {
        type = "norm",
        expression = placeholder_expr_node("X", "variable"),
        p_value = placeholder_expr_node("inf", "variable")
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse with spaces: ||  B  ||  _  {  p  }", function()
      local input = "||  B  ||  _  {  p  }"
      local expected_ast = {
        type = "norm",
        expression = placeholder_expr_node("B", "variable"),
        p_value = placeholder_expr_node("p", "variable")
      }
      assert.are.same(expected_ast, parse_input(input))
    end)
  end)

  describe("Valid norm notations using \\|...\\|", function()
    it("should parse \\|A\\| (no subscript)", function()
      local input = "\\|A\\|"
      local expected_ast = {
        type = "norm",
        expression = placeholder_expr_node("A", "variable"),
        p_value = nil
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\|v\\|_1 (numeric subscript)", function()
      local input = "\\|v\\|_1"
      local expected_ast = {
        type = "norm",
        expression = placeholder_expr_node("v", "variable"),
        p_value = placeholder_expr_node("1", "number")
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\|Matrix\\|_F (single letter variable subscript)", function()
      local input = "\\|Matrix\\|_F"
      local expected_ast = {
        type = "norm",
        expression = placeholder_expr_node("Matrix", "variable"),
        p_value = { type = "variable", name = "F" }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\|Y\\|_{max} (braced variable subscript)", function()
      local input = "\\|Y\\|_{max}"
      local expected_ast = {
        type = "norm",
        expression = placeholder_expr_node("Y", "variable"),
        p_value = placeholder_expr_node("max", "variable")
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse with spaces: \\|  C  \\|  _  {  fro  }", function()
      local input = "\\|  C  \\|  _  {  fro  }"
      local expected_ast = {
        type = "norm",
        expression = placeholder_expr_node("C", "variable"),
        p_value = placeholder_expr_node("fro", "variable")
      }
      assert.are.same(expected_ast, parse_input(input))
    end)
  end)


  describe("Invalid norm notations", function()
    it("should not parse ||A (missing closing delimiter)", function()
      assert.is_nil(parse_input("||A"))
    end)

    it("should not parse A|| (missing opening delimiter)", function()
      assert.is_nil(parse_input("A||"))
    end)

    it("should not parse \\|A (missing closing delimiter)", function()
      assert.is_nil(parse_input("\\|A"))
    end)

    it("should not parse A\\| (missing opening delimiter)", function()
      assert.is_nil(parse_input("A\\|"))
    end)

    it("should not parse ||A||_ (incomplete subscript)", function()
      assert.is_nil(parse_input("||A||_"))
    end)

    it("should not parse \\|v\\|_{ (incomplete subscript with brace)", function()
      assert.is_nil(parse_input("\\|v\\|_{"))
    end)

    it("should not parse || (empty content)", function()
      assert.is_nil(parse_input("||"))
    end)

    it("should not parse \\|\\| (empty content with LaTeX delimiter)", function()
      assert.is_nil(parse_input("\\|\\|"))
    end)

    it("should not parse |A| (single pipe, should be determinant or absolute value)", function()
      assert.is_nil(parse_input("|A|"))
    end)
  end)
end)
