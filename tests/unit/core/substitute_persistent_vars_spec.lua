-- tests/unit/core/substitute_persistent_vars_spec.lua
-- Tests for the substitute_persistent_vars function.

local engine = require 'tungsten.core.engine'

describe("substitute_persistent_vars", function()
  it("replaces variables with parentheses", function()
    local vars = { x = "5", y = "10" }
    local result = engine.substitute_persistent_vars("x + y", vars)
    assert.are.equal("(5) + (10)", result)
  end)

  it("replaces longer names first", function()
    local vars = { x = "1", xx = "2" }
    local result = engine.substitute_persistent_vars("xx + x", vars)
    assert.are.equal("(2) + (1)", result)
  end)

  it("does not replace partial words", function()
    local vars = { x = "5" }
    local result = engine.substitute_persistent_vars("yxx + x", vars)
    assert.are.equal("yxx + (5)", result)
  end)

  it("wraps substitutions in parentheses", function()
    local vars = { x = "1+1" }
    local result = engine.substitute_persistent_vars("2 * x", vars)
    assert.are.equal("2 * (1+1)", result)
  end)

  it("substitutes recursively when values reference other vars", function()
    local vars = { x = "y", y = "3" }
    local result = engine.substitute_persistent_vars("x", vars)
    assert.are.equal("((3))", result)
  end)

  it("is reasonably fast on large input", function()
    local vars = { x = "42" }
    local large = ("x + "):rep(10000)
    local start = os.clock()
    engine.substitute_persistent_vars(large, vars)
    assert.is_true(os.clock() - start < 0.5)
  end)

  
  it("returns input unchanged when no variables provided", function()
    local result = engine.substitute_persistent_vars("x + y", nil)
    assert.are.equal("x + y", result)
  end)
end)
