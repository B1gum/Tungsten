-- tests/unit/domains/calculus/rules/limit_spec.lua

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local lpeg = require "lpeglabel"
local P, C, R, S = lpeg.P, lpeg.C, lpeg.R, lpeg.S

local LimitRule

local mock_tokenizer_module
local mock_ast_module
local modules_to_reset = {
  "tungsten.domains.calculus.rules.limit",
  "tungsten.core.tokenizer",
  "tungsten.core.ast",
}

local test_grammar_table_definition
local compiled_test_grammar

local function placeholder_node(node_type, val_str, original_type_if_known)
  return { type = node_type, value_str = val_str, original_type = original_type_if_known or node_type }
end


describe("Calculus Limit Rule: tungsten.domains.calculus.rules.limit", function()

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
      end,

      create_limit_node = function(variable, point, expression)
        return {
          type = "limit",
          variable = variable,
          point = point,
          expression = expression
        }
      end
    }
    package.loaded["tungsten.core.ast"] = mock_ast_module

    LimitRule = require("tungsten.domains.calculus.rules.limit")

    test_grammar_table_definition = {
      "TestEntryPoint",

      TestEntryPoint = LimitRule * -P(1),

      Expression = (
        P("{x^2 + 2x - 3}") / function() return placeholder_node("placeholder_expr", "{x^2 + 2x - 3}", "complex_braced_in_mock") end +
        P("x^2 + 2x - 3") / function() return placeholder_node("placeholder_expr", "x^2 + 2x - 3", "complex_unbraced_in_mock") end +
        (P("1") * P("/") * P("n")) / function() return placeholder_node("placeholder_expr", "1/n", "fraction") end +
        (P("t") * P("^") * P("2")) / function() return placeholder_node("placeholder_expr", "t^2", "power") end +
        (P("f") * P("(") * P("x") * P(")")) / function() return placeholder_node("placeholder_expr", "f(x)", "function_call") end +
        mock_tokenizer_module.number +
        mock_tokenizer_module.variable +
        (P("\\infty") / function() return { type = "symbol", name = "infinity" } end)
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

  describe("Basic limit parsing", function()
    it("should parse \\lim_{x \\to 0} x (braced expression implied)", function()
      local input = "\\lim_{x \\to 0} x"
      local expected_ast = {
        type = "limit",
        variable = { type = "variable", name = "x" },
        point = { type = "number", value = 0 },
        expression = { type = "variable", name = "x" }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\lim_{x \\to 0} {x} (explicitly braced simple expression)", function()
      local input = "\\lim_{x \\to 0} {x}"
      local expected_ast = {
        type = "limit",
        variable = { type = "variable", name = "x" },
        point = { type = "number", value = 0 },
        expression = { type = "variable", name = "x" }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\lim_{t \\to a} t^2 (unbraced complex expression)", function()
      local input = "\\lim_{t \\to a} t^2"
      local expected_ast = {
        type = "limit",
        variable = { type = "variable", name = "t" },
        point = { type = "variable", name = "a" },
        expression = placeholder_node("placeholder_expr", "t^2", "power")
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\lim_{t \\to a} {t^2} (braced complex expression)", function()
      local input = "\\lim_{t \\to a} {t^2}"
      local expected_ast = {
        type = "limit",
        variable = { type = "variable", name = "t" },
        point = { type = "variable", name = "a" },
        expression = placeholder_node("placeholder_expr", "t^2", "power")
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\lim_{n \\to \\infty} 1/n", function()
      local input = "\\lim_{n \\to \\infty} 1/n"
      local expected_ast = {
        type = "limit",
        variable = { type = "variable", name = "n" },
        point = { type = "symbol", name = "infinity" },
        expression = placeholder_node("placeholder_expr", "1/n", "fraction")
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\lim_{x \\to 1} {x^2 + 2x - 3} (braced very complex expression)", function()
      local input = "\\lim_{x \\to 1} {x^2 + 2x - 3}"
      local expected_ast = {
        type = "limit",
        variable = { type = "variable", name = "x" },
        point = { type = "number", value = 1 },
        expression = placeholder_node("placeholder_expr", "x^2 + 2x - 3", "complex_unbraced_in_mock")
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\lim_{x \\to 1} x^2 + 2x - 3 (unbraced very complex expression)", function()
      local input = "\\lim_{x \\to 1} x^2 + 2x - 3"
      local expected_ast = {
        type = "limit",
        variable = { type = "variable", name = "x" },
        point = { type = "number", value = 1 },
        expression = placeholder_node("placeholder_expr", "x^2 + 2x - 3", "complex_unbraced_in_mock")
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse \\lim_{y \\to myPoint} f(x)", function()
        local input = "\\lim_{y \\to myPoint} f(x)"
        local expected_ast = {
            type = "limit",
            variable = { type = "variable", name = "y"},
            point = { type = "variable", name = "myPoint"},
            expression = placeholder_node("placeholder_expr", "f(x)", "function_call")
        }
        assert.are.same(expected_ast, parse_input(input))
    end)
  end)

  describe("Spacing variations", function()
    it("should parse with extra spaces: \\lim _ { x \\to 0 } { x }", function()
      local input = "\\lim _ { x \\to 0 } { x }"
      local expected_ast = {
        type = "limit",
        variable = { type = "variable", name = "x" },
        point = { type = "number", value = 0 },
        expression = { type = "variable", name = "x" }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse with no spaces: \\lim_{x\\to0}{x}", function()
      local input = "\\lim_{x\\to0}{x}"
      local expected_ast = {
        type = "limit",
        variable = { type = "variable", name = "x" },
        point = { type = "number", value = 0 },
        expression = { type = "variable", name = "x" }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse with space before unbraced expression: \\lim_{x \\to 0}  x", function()
      local input = "\\lim_{x \\to 0}  x"
      local expected_ast = {
        type = "limit",
        variable = { type = "variable", name = "x" },
        point = { type = "number", value = 0 },
        expression = { type = "variable", name = "x" }
      }
      assert.are.same(expected_ast, parse_input(input))
    end)
  end)

  describe("Invalid syntax (should not parse to limit)", function()
    it("should not parse if \\lim is missing: _{x \\to 0} x", function()
      assert.is_nil(parse_input("_{x \\to 0} x"))
    end)

    it("should not parse if subscript is missing: \\lim x", function()
      assert.is_nil(parse_input("\\lim x"))
    end)

    it("should not parse if variable in subscript is missing: \\lim_{\\to 0} x", function()
      assert.is_nil(parse_input("\\lim_{\\to 0} x"))
    end)

    it("should not parse if arrow \\to is missing: \\lim_{x 0} x", function()
      assert.is_nil(parse_input("\\lim_{x 0} x"))
    end)

    it("should not parse if point in subscript is missing: \\lim_{x \\to} x", function()
      assert.is_nil(parse_input("\\lim_{x \\to} x"))
    end)

    it("should not parse if main expression is missing: \\lim_{x \\to 0}", function()
      assert.is_nil(parse_input("\\lim_{x \\to 0}"))
    end)

    it("should not parse with mismatched braces in subscript: \\lim_{x \\to 0 x", function()
      assert.is_nil(parse_input("\\lim_{x \\to 0 x"))
    end)

    it("should not parse with mismatched braces for expression: \\lim_{x \\to 0} {x", function()
      assert.is_nil(parse_input("\\lim_{x \\to 0} {x"))
    end)

    it("should not parse if subscript has only variable: \\lim_{x} x", function()
      assert.is_nil(parse_input("\\lim_{x} x"))
    end)
  end)
end)
