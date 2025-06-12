-- tests/unit/domains/differential_equations/rules/ode_system_spec.lua
-- Busted tests for the ODE system parsing rule.

package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local lpeg = require "lpeg"
local P, V, C, R, S, Ct = lpeg.P, lpeg.V, lpeg.C, lpeg.R, lpeg.S, lpeg.Ct

describe("Differential Equations ODE System Rule", function()
  local test_grammar
  local function parse_input(input_str)
    assert(test_grammar, "Test grammar was not compiled for test")
    return lpeg.match(test_grammar, input_str)
  end

  before_each(function()
    local mock_tk = {
      space = S(" \t\n\r")^0,
    }
    package.loaded["tungsten.core.tokenizer"] = mock_tk
    package.loaded["tungsten.core.ast"] = {
      create_ode_system_node = function(odes)
        return { type = "ode_system", equations = odes }
      end,
    }

    local g = {}
    g[1] = V"ODESystem"

    g.ODE = (C(R("az")) * P("=") * C(R("az"))) / function(l, r)
      return { type = "ode", lhs = l, rhs = r }
    end

    local separator = mock_tk.space * (P(";") + P"\\\\") * mock_tk.space
    g.ODESystem = Ct(V"ODE" * (separator * V"ODE")^0) / function(odes)
      return package.loaded["tungsten.core.ast"].create_ode_system_node(odes)
    end

    test_grammar = P(g)
  end)

  it("should parse a two-equation system with a semicolon separator", function()
    local result = parse_input("a=b ; c=d")
    assert.is_table(result)
    assert.are.same("ode_system", result.type)
    assert.are.same(2, #result.equations)
    assert.are.same("ode", result.equations[1].type)
    assert.are.same("a", result.equations[1].lhs)
    assert.are.same("d", result.equations[2].rhs)
  end)

  it("should parse a three-equation system with a double-backslash separator", function()
    local result = parse_input("x=y \\\\ y=z \\\\ z=x")
    assert.is_table(result)
    assert.are.same("ode_system", result.type)
    assert.are.same(3, #result.equations)
    assert.are.same("ode", result.equations[3].type)
    assert.are.same("z", result.equations[3].lhs)
  end)
end)
