-- tests/unit/domains/differential_equations/rules/wronskian_spec.lua
-- Busted tests for the Wronskian parsing rule.

local lpeg = require "lpeglabel"
local P, V, C, R, S, Ct = lpeg.P, lpeg.V, lpeg.C, lpeg.R, lpeg.S, lpeg.Ct

describe("Differential Equations Wronskian Rule", function()
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
      number = C(R("09")^1) / function(s)
        return { type = "number", value = tonumber(s) }
      end,
    }
    package.loaded["tungsten.core.tokenizer"] = mock_tk
    package.loaded["tungsten.core.ast"] = {
      create_wronskian_node = function(functions_list)
        return { type = "wronskian", functions = functions_list }
      end,
      create_subscript_node = function(base, sub)
        return { type = "subscript", base = base, subscript = sub }
      end,
    }

    local g = {}
    g.Atom = mock_tk.variable + mock_tk.number
    g.Subscript = (V("Atom") * P("_") * V("Atom")) / function(base, sub)
      return package.loaded["tungsten.core.ast"].create_subscript_node(base, sub)
    end
    g.Expression = V("Subscript") + V("Atom")

    local expression_list = Ct(V("Expression") * (mock_tk.space * P(",") * mock_tk.space * V("Expression"))^0)

    g.Wronskian = P("W") * mock_tk.space * P("(") * mock_tk.space * expression_list * mock_tk.space * P(")") / function(functions)
      return package.loaded["tungsten.core.ast"].create_wronskian_node(functions)
    end

    g[1] = V("Wronskian")
    test_grammar = P(g)
  end)

  it("should parse the Wronskian of two functions: W(f, g)", function()
    local result = parse_input("W(f, g)")
    assert.is_table(result)
    assert.are.same("wronskian", result.type)
    assert.are.same(2, #result.functions)
    assert.are.same("f", result.functions[1].name)
    assert.are.same("g", result.functions[2].name)
  end)

  it("should parse the Wronskian of three functions with subscripts: W(y_1, y_2, y_3)", function()
    local result = parse_input("W(y_1, y_2, y_3)")
    assert.is_table(result)
    assert.are.same("wronskian", result.type)
    assert.are.same(3, #result.functions)
    assert.are.same("subscript", result.functions[1].type)
    assert.are.same("y", result.functions[1].base.name)
    assert.are.same(1, result.functions[1].subscript.value)
    assert.are.same(2, result.functions[2].subscript.value)
    assert.are.same(3, result.functions[3].subscript.value)
  end)

  it("should parse the Wronskian of a single function: W(x)", function()
    local result = parse_input("W(x)")
    assert.is_table(result)
    assert.are.same("wronskian", result.type)
    assert.are.same(1, #result.functions)
    assert.are.same("x", result.functions[1].name)
  end)
end)
