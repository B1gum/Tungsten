package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local lpeg = require "lpeglabel"
local P, V, C, R, S = lpeg.P, lpeg.V, lpeg.C, lpeg.R, lpeg.S

describe("Differential Equations Convolution Rule", function()
  local test_grammar
  local function parse_input(input_str)
    assert(test_grammar, "Test grammar was not compiled for test")
    return lpeg.match(test_grammar, input_str)
  end

  before_each(function()
    package.loaded["tungsten.core.tokenizer"] = { space = S(" \t\n\r")^0 }
    package.loaded["tungsten.core.ast"] = {
      create_convolution_node = function(left, right)
        return { type = "convolution", left = left, right = right }
      end,
      create_function_call_node = function(name, args)
        return { type = "function_call", name_node = name, args = args }
      end,
    }
    package.loaded["tungsten.domains.differential_equations.rules.convolution"] = nil

    local ConvolutionRule = require "tungsten.domains.differential_equations.rules.convolution"

    local g = {}
    g[1] = V "Expression"

    g.Variable = C(R("az", "AZ")^1) / function(s) return { type = "variable", name = s } end
    g.Parens = P "(" * V "Expression" * P ")"

    g.Callable = g.Parens + g.Variable

    g.FunctionCall = (V "Callable" * P "(" * V "Variable" * P ")") / function(callable, arg)
      return package.loaded["tungsten.core.ast"].create_function_call_node(callable, { arg })
    end

    g.Unary = g.FunctionCall + g.Callable

    g.Convolution = ConvolutionRule

    g.Expression = g.Convolution + g.Unary

    test_grammar = P(g)
  end)

  it("should parse the infix convolution: f(t) \\ast g(t)", function()
    local result = parse_input("f(t) \\ast g(t)")
    assert.is_table(result)
    assert.are.same("convolution", result.type)
    assert.are.same("function_call", result.left.type)
    assert.are.same("function_call", result.right.type)
  end)

  it("should parse the function call style convolution: (f \\ast g)(t)", function()
    local result = parse_input("(f \\ast g)(t)")
    assert.is_table(result)
    assert.are.same("function_call", result.type)
    assert.is_table(result.name_node)
    assert.are.same("convolution", result.name_node.type)
  end)
end)
