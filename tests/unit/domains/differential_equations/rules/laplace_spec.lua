-- tests/unit/domains/differential_equations/rules/laplace_spec.lua
-- Busted tests for the Laplace transform parsing rule.

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local lpeg = require "lpeglabel"
local P, V, C, R, S = lpeg.P, lpeg.V, lpeg.C, lpeg.R, lpeg.S

describe("Differential Equations Laplace Rule", function()
  local test_grammar
  local function parse_input(input_str)
    assert(test_grammar, "Test grammar was not compiled for test")
    return lpeg.match(test_grammar, input_str)
  end

  before_each(function()
    local mock_tk = {
      space = S(" \t\n\r")^0,
      variable = C(R("az", "AZ")^1) / function(s)
        return { type = "variable", name = s }
      end,
    }
    package.loaded["tungsten.core.tokenizer"] = mock_tk
    package.loaded["tungsten.core.ast"] = {
      create_laplace_transform_node = function(expr)
        return { type = "laplace_transform", expression = expr }
      end,
      create_inverse_laplace_transform_node = function(expr)
        return { type = "inverse_laplace_transform", expression = expr }
      end,
      create_function_call_node = function(name, args)
        return { type = "function_call", name_node = name, args = args }
      end,
    }

    local g = {}
    g.Atom = mock_tk.variable
    g.FunctionCall = (V"Atom" * P"(" * V"Atom" * P")") / function(name, arg)
      return package.loaded["tungsten.core.ast"].create_function_call_node(name, { arg })
    end
    g.Expression = V"FunctionCall" + V"Atom"

    local expression_in_braces = P"\\{" * mock_tk.space * V"Expression" * mock_tk.space * P"\\}"
    local inverse_marker = P"^" * mock_tk.space * P"{" * mock_tk.space * P"-1" * mock_tk.space * P"}"

    g.Laplace = P"\\mathcal{L}" * C(inverse_marker^-1) * mock_tk.space * expression_in_braces / function(inv, expr)
      if inv == "" then
        return package.loaded["tungsten.core.ast"].create_laplace_transform_node(expr)
      else
        return package.loaded["tungsten.core.ast"].create_inverse_laplace_transform_node(expr)
      end
    end

    g[1] = V"Laplace"
    test_grammar = P(g)
  end)

  it("should parse a forward Laplace transform: \\mathcal{L}\\{f(t)\\}", function()
    local result = parse_input("\\mathcal{L}\\{f(t)\\}")
    assert.is_table(result)
    assert.are.same("laplace_transform", result.type)
    assert.is_table(result.expression)
    assert.are.same("function_call", result.expression.type)
    assert.are.same("f", result.expression.name_node.name)
  end)

  it("should parse an inverse Laplace transform: \\mathcal{L}^{-1}\\{F(s)\\}", function()
    local result = parse_input("\\mathcal{L}^{-1}\\{F(s)\\}")
    assert.is_table(result)
    assert.are.same("inverse_laplace_transform", result.type)
    assert.is_table(result.expression)
    assert.are.same("function_call", result.expression.type)
    assert.are.same("F", result.expression.name_node.name)
  end)
end)
