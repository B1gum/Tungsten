-- tests/unit/domains/calculus/rules/integral_spec.lua

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local lpeg = require "lpeg"
local P, V, C, R, S = lpeg.P, lpeg.V, lpeg.C, lpeg.R, lpeg.S

local IntegralRule

local mock_tokenizer_module
local mock_ast_module
local modules_to_reset = {
  "tungsten.domains.calculus.rules.integral",
  "tungsten.core.tokenizer",
  "tungsten.core.ast",
}

local test_grammar_table_definition
local compiled_test_grammar

local function placeholder_node(node_type, val_str, original_type_if_known)
  return { type = node_type, value_str = val_str, original_type = original_type_if_known or node_type }
end


describe("Calculus Integral Rule: tungsten.domains.calculus.rules.integral", function()

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
      create_indefinite_integral_node = function(integrand, variable)
        return {
          type = "indefinite_integral",
          integrand = integrand,
          variable = variable
        }
      end,

      create_definite_integral_node = function(integrand, variable, lower_bound, upper_bound)
        return {
          type = "definite_integral",
          integrand = integrand,
          variable = variable,
          lower_bound = lower_bound,
          upper_bound = upper_bound
        }
      end
    }
    package.loaded["tungsten.core.ast"] = mock_ast_module

    IntegralRule = require("tungsten.domains.calculus.rules.integral")

    test_grammar_table_definition = {
      "TestEntryPoint",

      TestEntryPoint = IntegralRule * -P(1),

      Expression = (
        P("t^2") / function() return placeholder_node("placeholder_expr", "t^2", "power") end +
        P("x^2") / function() return placeholder_node("placeholder_expr", "x^2", "power") end +
        P("f(t)") / function() return placeholder_node("placeholder_expr", "f(t)", "function_call") end +
        P("sin(y)") / function() return placeholder_node("placeholder_expr", "sin(y)", "function_call_sin") end +
        P("E") / function() return placeholder_node("placeholder_expr", "E", "constant_E") end +
        P("-\\infty") / function() return { type = "symbol", name = "infinity" } end +
        mock_tokenizer_module.number +
        mock_tokenizer_module.variable +
        (P("\\pi") / function() return { type = "symbol", name = "pi" } end) +
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

  local indefinite_integrals_data = {
    { "x \\mathrm{d}x", "\\int x %s \\mathrm{d}x", { type = "variable", name = "x" }, "x" },
    { "t^2 \\mathrm{d}t", "\\int t^2 %s \\mathrm{d}t", placeholder_node("placeholder_expr", "t^2", "power"), "t" },
    { "f(t) d t (note space in 'd t')", "\\int f(t) %s d t", placeholder_node("placeholder_expr", "f(t)", "function_call"), "t" },
    { "sin(y) dAlpha (multichar var)", "\\int sin(y) %s dAlpha", placeholder_node("placeholder_expr", "sin(y)", "function_call_sin"), "Alpha" },
  }

  local definite_integrals_data = {
    { "_{0}^{1} x \\mathrm{d}x", "\\int_{0}^{1} x %s \\mathrm{d}x", {type="number",value=0}, {type="number",value=1}, {type="variable",name="x"}, "x" },
    { "_{a}^{b} t^2 \\mathrm{d}t", "\\int_{a}^{b} t^2 %s \\mathrm{d}t", {type="variable",name="a"}, {type="variable",name="b"}, placeholder_node("placeholder_expr", "t^2", "power"), "t" },
    { "_{-\\infty}^{\\infty} f(t) d t", "\\int_{-\\infty}^{\\infty} f(t) %s d t", {type="symbol",name="infinity"}, {type="symbol",name="infinity"}, placeholder_node("placeholder_expr", "f(t)", "function_call"), "t" },
    { "_{0}^{\\pi} sin(y) dAlpha", "\\int_{0}^{\\pi} sin(y) %s dAlpha", {type="number",value=0}, {type="symbol",name="pi"}, placeholder_node("placeholder_expr", "sin(y)", "function_call_sin"), "Alpha"},
  }

  local spacers = {
    { name = "no spacer", latex = "" },
    { name = "\\,", latex = "\\," },
    { name = "\\.", latex = "\\." },
    { name = "\\;", latex = "\\;" },
  }

  local d_operators = {
    { name = "\\mathrm{d}", latex_d = "\\mathrm{d}"},
    { name = "d", latex_d = "d"},
  }

  describe("Indefinite Integrals", function()
    for _, data in ipairs(indefinite_integrals_data) do
      local desc_suffix, input_template, integrand_ast, var_name = unpack(data)
      for _, d_op in ipairs(d_operators) do
        for _, spacer in ipairs(spacers) do
          local test_name = string.format("should parse %s with %s and %s", desc_suffix, d_op.name, spacer.name)
          local final_input_template = string.gsub(input_template, "\\mathrm{d}", d_op.latex_d)
          local input_str = string.format(final_input_template, spacer.latex)

          it(test_name, function()
            local expected_ast = {
              type = "indefinite_integral",
              integrand = integrand_ast,
              variable = { type = "variable", name = var_name }
            }
            local parsed = parse_input(input_str)
            assert.are.same(expected_ast, parsed)
          end)
        end
      end
    end
  end)

  describe("Definite Integrals", function()
    for _, data in ipairs(definite_integrals_data) do
      local desc_suffix, input_template, lower_b, upper_b, integrand_ast, var_name = unpack(data)

      for _, d_op in ipairs(d_operators) do
        for _, spacer in ipairs(spacers) do
          local test_name = string.format("should parse %s with %s and %s", desc_suffix, d_op.name, spacer.name)
          local final_input_template = string.gsub(input_template, "\\mathrm{d}", d_op.latex_d)
          local input_str = string.format(final_input_template, spacer.latex)

          it(test_name, function()
            local expected_ast = {
              type = "definite_integral",
              integrand = integrand_ast,
              variable = { type = "variable", name = var_name },
              lower_bound = lower_b,
              upper_bound = upper_b
            }
            local parsed = parse_input(input_str)
            if not require("luassert.match").equals(expected_ast, parsed) then
                print("DEBUG: Test may fail. Input:", input_str)
                print("DEBUG: Expected AST:", vim.inspect(expected_ast))
                print("DEBUG: Parsed AST:", vim.inspect(parsed))
            end
            assert.are.same(expected_ast, parsed)
          end)
        end
      end
    end
  end)

  describe("Spacing and Edge Cases", function()
    it("should parse definite integral with no space after \\int: \\int_{0}^{1}x dx", function()
      local input = "\\int_{0}^{1}x dx"
      local expected_ast = {
        type = "definite_integral",
        integrand = {type="variable", name="x"},
        variable = {type="variable", name="x"},
        lower_bound = {type="number", value=0},
        upper_bound = {type="number", value=1}
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should parse indefinite integral with no space after \\int: \\int x dx", function()
      local input = "\\int x dx"
      local expected_ast = {
        type = "indefinite_integral",
        integrand = {type="variable", name="x"},
        variable = {type="variable", name="x"}
      }
      assert.are.same(expected_ast, parse_input(input))
    end)

    it("should handle multiple spaces between components: \\int  _{0}  ^{1}  x   dx", function()
      local input = "\\int  _{0}  ^{1}  x   dx"
       local expected_ast = {
        type = "definite_integral",
        integrand = {type="variable", name="x"},
        variable = {type="variable", name="x"},
        lower_bound = {type="number", value=0},
        upper_bound = {type="number", value=1}
      }
      assert.are.same(expected_ast, parse_input(input))
    end)
  end)


  describe("Invalid Syntax", function()
    it("should not parse if \\int is missing: _{0}^{1} x dx", function()
      assert.is_nil(parse_input("_{0}^{1} x dx"))
    end)
    it("should not parse if integrand is missing: \\int dx", function()
      assert.is_nil(parse_input("\\int dx"))
    end)
    it("should not parse if integrand is missing (definite): \\int_{0}^{1} dx", function()
      assert.is_nil(parse_input("\\int_{0}^{1} dx"))
    end)
    it("should not parse if differential 'd' is missing: \\int x", function()
      assert.is_nil(parse_input("\\int x"))
    end)
    it("should not parse if variable of integration is missing: \\int x d", function()
      assert.is_nil(parse_input("\\int x d"))
    end)
    it("should not parse definite integral with only lower bound: \\int_{0} x dx", function()
      assert.is_nil(parse_input("\\int_{0} x dx"))
    end)
    it("should not parse definite integral with only upper bound: \\int^{1} x dx", function()
      assert.is_nil(parse_input("\\int^{1} x dx"))
    end)
    it("should not parse definite integral with bounds in wrong order: \\int^{1}_{0} x dx", function()
      assert.is_nil(parse_input("\\int^{1}_{0} x dx"))
    end)
     it("should not parse if bounds are not in braces: \\int_0^1 x dx", function()
      assert.is_nil(parse_input("\\int_0^1 x dx"))
    end)
  end)
end)
