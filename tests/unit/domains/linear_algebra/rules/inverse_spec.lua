-- tests/unit/domains/linear_algebra/rules/inverse_spec.lua
package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local lpeg = require "lpeg"
local P, V, C, R, S, Cg, Ct, Cf = lpeg.P, lpeg.V, lpeg.C, lpeg.R, lpeg.S, lpeg.Cg, lpeg.Ct, lpeg.Cf

local InverseRule

local mock_tokenizer_module
local mock_ast_module
local modules_to_reset = {
  "tungsten.domains.linear_algebra.rules.inverse",
  "tungsten.core.tokenizer",
  "tungsten.core.ast",
}

local test_grammar_table_definition
local compiled_test_grammar

local function base_node(name_or_val, type)
  if type == "number" then
    return { type = "number", value = name_or_val }
  elseif type == "group" then
    return { type = "group_placeholder", content_str = name_or_val}
  else
    return { type = "variable", name = name_or_val }
  end
end

describe("Linear Algebra Inverse Rule: tungsten.domains.linear_algebra.rules.inverse", function()

  before_each(function()
    for _, name in ipairs(modules_to_reset) do
      package.loaded[name] = nil
    end

    mock_tokenizer_module = {
      space = S(" \t\n\r")^0,
      lbrace = P("{"),
      rbrace = P("}"),
      variable = C(R("AZ","az") * (R("AZ","az","09")^0)) / function(s) return base_node(s, "variable") end,
      number = C(R("09")^1 * (P(".")*R("09")^1)^-1) / function(s) return base_node(tonumber(s), "number") end,
      lparen = P("("),
      rparen = P(")"),
    }
    package.loaded["tungsten.core.tokenizer"] = mock_tokenizer_module

    mock_ast_module = {
      create_inverse_node = function(expression_ast)
        return { type = "inverse", expression = expression_ast }
      end,
      create_superscript_node = function(b, e) return {type="superscript", base=b, exponent=e} end,
      create_subscript_node = function(b, s) return {type="subscript", base=b, subscript=s} end,
    }
    package.loaded["tungsten.core.ast"] = mock_ast_module

    InverseRule = require("tungsten.domains.linear_algebra.rules.inverse")

    local mock_atom_base_item = mock_tokenizer_module.variable +
                                mock_tokenizer_module.number +
                                (mock_tokenizer_module.lparen * mock_tokenizer_module.space *
                                 C((P(1) - mock_tokenizer_module.rparen)^0) *
                                 mock_tokenizer_module.space * mock_tokenizer_module.rparen /
                                 function(c_str) return base_node(c_str, "group") end)


    test_grammar_table_definition = {
      "TestEntryPoint",
      TestEntryPoint = InverseRule * -P(1),
      AtomBaseItem = mock_atom_base_item,
    }
    compiled_test_grammar = P(test_grammar_table_definition)
  end)

  after_each(function()
    for _, name in ipairs(modules_to_reset) do
      package.loaded[name] = nil
    end
  end)

  local function parse_input(input_str)
    assert(compiled_test_grammar, "Test grammar w[48;56;204;1792;2856tas not compiled for this test run.")
    local result = lpeg.match(compiled_test_grammar, input_str)
    return result
  end

  describe("Valid inverse notations", function()
    it("should parse A ^ { -1 }", function()
      local input = "A ^ { -1 }"
      local expected_ast = {
        type = "inverse",
        expression = base_node("A", "variable")
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse VarName ^ { -1 } (multi-character variable)", function()
      local input = "VarName ^ { -1 }"
      local expected_ast = {
        type = "inverse",
        expression = base_node("VarName", "variable")
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse (AB) ^ { -1 } (grouped expression as base - mock, input adjusted)", function()
      local input = "(AB) ^ { -1 }"
      local expected_ast = {
        type = "inverse",
        expression = base_node("AB", "group")
      }
      local parsed = parse_input(input)
      assert.are.same(expected_ast, parsed)
    end)

    it("should parse with varied spaces: M  ^  {  -1  }", function()
      local input = "M  ^  {  -1  }"
      local expected_ast = {
        type = "inverse",
        expression = base_node("M", "variable")
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse A^{-1}", function()
      local input = "A^{-1}"
      local expected_ast = {
        type = "inverse",
        expression = base_node("A", "variable")
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse A ^ { - 1 }", function()
      local input = "A ^ { - 1 }"
      local expected_ast = {
        type = "inverse",
        expression = base_node("A", "variable")
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

  end)

  describe("Invalid inverse notations or edge cases", function()
    it("should not parse A ^ -1 (missing braces around -1)", function()
      assert.is_nil(parse_input("A ^ -1"))
    end)

    it("should not parse A ^ {1} (wrong exponent)", function()
      assert.is_nil(parse_input("A ^ {1}"))
    end)

    it("should not parse A ^ {-2} (wrong exponent)", function()
      assert.is_nil(parse_input("A ^ {-2}"))
    end)

    it("should not parse A ^ {} (empty exponent)", function()
      assert.is_nil(parse_input("A ^ {}"))
    end)

    it("should not parse A^ (incomplete)", function()
      assert.is_nil(parse_input("A^"))
    end)

    it("should not parse A ^ { -1 (incomplete braces)", function()
      assert.is_nil(parse_input("A ^ { -1"))
    end)

    it("should not parse ^ { -1 } A (operator before base)", function()
      assert.is_nil(parse_input("^ { -1 } A"))
    end)
  end)
end)
