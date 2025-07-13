-- tests/unit/domains/calculus/rules/partial_derivatives_spec.lua

local lpeg = require "lpeglabel"
local P, V, C, R, S = lpeg.P, lpeg.V, lpeg.C, lpeg.R, lpeg.S

local PartialDerivativeRule

local mock_tokenizer_module
local mock_ast_module
local modules_to_reset = {
  "tungsten.domains.calculus.rules.partial_derivatives",
  "tungsten.core.tokenizer",
  "tungsten.core.ast",
}

local test_grammar_table_definition
local compiled_test_grammar

local function placeholder_node(node_type, val_str, original_type_if_known)
  return { type = node_type, value_str = val_str, original_type = original_type_if_known or node_type }
end


describe("Calculus Partial Derivative Rule: tungsten.domains.calculus.rules.partial_derivatives", function()

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

      create_differentiation_term_node = function(variable_node, order_node)
        return {
          type = "differentiation_term",
          variable = variable_node,
          order = order_node or { type = "number", value = 1 }
        }
      end,
      create_partial_derivative_node = function(expression, overall_order, variables_list)
        return {
          type = "partial_derivative",
          expression = expression,
          overall_order = overall_order or { type = "number", value = #variables_list },
          variables = variables_list
        }
      end
    }
    package.loaded["tungsten.core.ast"] = mock_ast_module
    PartialDerivativeRule = require("tungsten.domains.calculus.rules.partial_derivatives")

    test_grammar_table_definition = {
      "TestEntryPoint",
      TestEntryPoint = PartialDerivativeRule * -P(1),

      AtomBase = (
        mock_tokenizer_module.number +
        mock_tokenizer_module.variable
      ),
      Expression = (
        P("f(x,y)") / function() return placeholder_node("placeholder_expr", "f(x,y)", "func_fxy") end +
        P("g(x)") / function() return placeholder_node("placeholder_expr", "g(x)", "func_gx") end +
        P("x^2y") / function() return placeholder_node("placeholder_expr", "x^2y", "term_x2y") end +
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

  local function var_term(var_name, order_val_or_name)
    local order_ast
    if type(order_val_or_name) == "number" then
      order_ast = { type = "number", value = order_val_or_name }
    else
      order_ast = { type = "variable", name = tostring(order_val_or_name) }
    end
    return { type = "differentiation_term", variable = { type = "variable", name = var_name }, order = order_ast }
  end


  describe("First-order Overall (Numerator \\partial)", function()
    it("should parse \\frac{\\partial}{\\partial x} f(x,y)", function()
      local input = "\\frac{\\partial}{\\partial x} f(x,y)"
      local expected = {
        type = "partial_derivative",
        expression = placeholder_node("placeholder_expr", "f(x,y)", "func_fxy"),
        overall_order = { type = "number", value = 1 },
        variables = { var_term("x", 1) }
      }
      assert.are.same(expected, parse_input(input))
    end)

    it("should parse \\frac{\\partial}{\\partial y^2} f(x,y) (order on var in den)", function()
      local input = "\\frac{\\partial}{\\partial y^2} f(x,y)"
      local expected = {
        type = "partial_derivative",
        expression = placeholder_node("placeholder_expr", "f(x,y)", "func_fxy"),
        overall_order = { type = "number", value = 1 },
        variables = { var_term("y", 2) }
      }
      assert.are.same(expected, parse_input(input))
    end)

    it("should parse \\frac{\\partial}{\\partial x \\partial y} {f(x,y)} (braced expr)", function()
      local input = "\\frac{\\partial}{\\partial x \\partial y} {f(x,y)}"
      local expected = {
        type = "partial_derivative",
        expression = placeholder_node("placeholder_expr", "f(x,y)", "func_fxy"),
        overall_order = { type = "number", value = 1 },
        variables = { var_term("x", 1), var_term("y", 1) }
      }
      assert.are.same(expected, parse_input(input))
    end)

    it("should parse \\frac{\\partial}{\\partial x^2 \\partial y^3} f(x,y)", function()
      local input = "\\frac{\\partial}{\\partial x^2 \\partial y^3} f(x,y)"
      local expected = {
        type = "partial_derivative",
        expression = placeholder_node("placeholder_expr", "f(x,y)", "func_fxy"),
        overall_order = { type = "number", value = 1 },
        variables = { var_term("x", 2), var_term("y", 3) }
      }
      assert.are.same(expected, parse_input(input))
    end)
  end)

  describe("Higher-order Overall (Numerator \\partial^ORDER)", function()
    it("should parse \\frac{\\partial^2}{\\partial x^2} f(x,y)", function()
      local input = "\\frac{\\partial^2}{\\partial x^2} f(x,y)"
      local expected = {
        type = "partial_derivative",
        expression = placeholder_node("placeholder_expr", "f(x,y)", "func_fxy"),
        overall_order = { type = "number", value = 2 },
        variables = { var_term("x", 2) }
      }
      assert.are.same(expected, parse_input(input))
    end)

    it("should parse \\frac{\\partial^N}{\\partial x^N} f(x,y) (variable order)", function()
      local input = "\\frac{\\partial^N}{\\partial x^N} f(x,y)"
      local expected = {
        type = "partial_derivative",
        expression = placeholder_node("placeholder_expr", "f(x,y)", "func_fxy"),
        overall_order = { type = "variable", name = "N" },
        variables = { var_term("x", "N") }
      }
      assert.are.same(expected, parse_input(input))
    end)

    it("should parse \\frac{\\partial^{M+N}}{\\partial x^M \\partial y^N} f(x,y) (braced overall order)", function()
      local input = "\\frac{\\partial^K}{\\partial x^M \\partial y^N} f(x,y)"
      local expected = {
        type = "partial_derivative",
        expression = placeholder_node("placeholder_expr", "f(x,y)", "func_fxy"),
        overall_order = { type = "variable", name = "K" },
        variables = { var_term("x", "M"), var_term("y", "N") }
      }
      assert.are.same(expected, parse_input(input))
    end)

    it("should parse \\frac{\\partial^3}{\\partial x \\partial y \\partial z} {x^2y}", function()
      local input = "\\frac{\\partial^3}{\\partial x \\partial y \\partial z} {x^2y}"
      local expected = {
        type = "partial_derivative",
        expression = placeholder_node("placeholder_expr", "x^2y", "term_x2y"),
        overall_order = { type = "number", value = 3 },
        variables = { var_term("x", 1), var_term("y", 1), var_term("z", 1) }
      }
      assert.are.same(expected, parse_input(input))
    end)

     it("should parse \\frac{\\partial^{2}}{\\partial x \\partial y} f(x,y) (mixed partial, overall order matches sum)", function()
      local input = "\\frac{\\partial^{2}}{\\partial x \\partial y} f(x,y)"
      local expected = {
        type = "partial_derivative",
        expression = placeholder_node("placeholder_expr", "f(x,y)", "func_fxy"),
        overall_order = { type = "number", value = 2 },
        variables = { var_term("x", 1), var_term("y", 1) }
      }
      assert.are.same(expected, parse_input(input))
    end)

    it("should parse from prompt: \\frac{\\partial^{<ORDER>}}{\\partial <VARIABLE> \\partial <VARIABLE>} <EXPR> (orders 1 in den)", function()
        local input = "\\frac{\\partial^N}{\\partial x \\partial y} g(x)"
        local expected = {
            type = "partial_derivative",
            expression = placeholder_node("placeholder_expr", "g(x)", "func_gx"),
            overall_order = {type = "variable", name = "N"},
            variables = { var_term("x",1), var_term("y",1) }
        }
        assert.are.same(expected, parse_input(input))
    end)
  end)

  describe("Exponent Variations (braced vs unbraced order)", function()
    it("should parse overall order with braces: \\frac{\\partial^{2}}{\\partial x^2} f(x,y)", function()
      local input = "\\frac{\\partial^{2}}{\\partial x^2} f(x,y)"
       local expected = {
        type = "partial_derivative",
        expression = placeholder_node("placeholder_expr", "f(x,y)", "func_fxy"),
        overall_order = { type = "number", value = 2 },
        variables = { var_term("x", 2) }
      }
      assert.are.same(expected, parse_input(input))
    end)
    it("should parse variable order with braces: \\frac{\\partial^2}{\\partial x^{2}} f(x,y)", function()
      local input = "\\frac{\\partial^2}{\\partial x^{2}} f(x,y)"
       local expected = {
        type = "partial_derivative",
        expression = placeholder_node("placeholder_expr", "f(x,y)", "func_fxy"),
        overall_order = { type = "number", value = 2 },
        variables = { var_term("x", 2) }
      }
      assert.are.same(expected, parse_input(input))
    end)
  end)

  describe("Invalid Syntax", function()
    it("should not parse if \\partial is missing in numerator: \\frac{^2}{\\partial x^2} f(x,y)", function()
      assert.is_nil(parse_input("\\frac{^2}{\\partial x^2} f(x,y)"))
    end)
    it("should not parse if variable is missing in denominator term: \\frac{\\partial}{\\partial^2} f(x,y)", function()
      assert.is_nil(parse_input("\\frac{\\partial}{\\partial^2} f(x,y)"))
    end)
    it("should not parse if \\partial is missing in a denominator term: \\frac{\\partial}{\\partial x y^2} f(x,y)", function()
      assert.is_nil(parse_input("\\frac{\\partial}{\\partial x y^2} f(x,y)"))
    end)
     it("should not parse if expression is missing: \\frac{\\partial}{\\partial x}", function()
      assert.is_nil(parse_input("\\frac{\\partial}{\\partial x}"))
    end)
    it("should not parse incomplete frac: \\frac{\\partial}{\\partial x", function()
      assert.is_nil(parse_input("\\frac{\\partial}{\\partial x"))
    end)
    it("should not parse empty denominator: \\frac{\\partial}{ } f(x,y)", function()
      assert.is_nil(parse_input("\\frac{\\partial}{ } f(x,y)"))
    end)
    it("should not parse empty numerator: \\frac{ }{\\partial x } f(x,y)", function()
      assert.is_nil(parse_input("\\frac{ }{\\partial x } f(x,y)"))
    end)
  end)
end)
