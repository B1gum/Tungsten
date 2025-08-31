local spy = require("luassert.spy")
local mock_utils = require("tests.helpers.mock_utils")

local function ast_node(type, props)
  props = props or {}
  props.type = type
  return props
end

describe("Equality classification", function()
  local classification
  local mock_free_vars
  local mock_ast

  before_each(function()
    mock_utils.reset_modules({
      "tungsten.domains.plotting.classification",
      "tungsten.domains.plotting.free_vars",
      "tungsten.core.ast",
    })

    mock_free_vars = {
      find = spy.new(function() return {} end),
    }
    package.loaded["tungsten.domains.plotting.free_vars"] = mock_free_vars

    mock_ast = {
      create_variable_node = function(name)
        return ast_node("variable", { name = name })
      end,
    }
    package.loaded["tungsten.core.ast"] = mock_ast

    classification = require("tungsten.domains.plotting.classification")
  end)

  it("classifies y = f(x) as explicit", function()
    local rhs = ast_node("function_call", { name = "cos", args = { "x" } })
    local eq = ast_node("equality", { lhs = mock_ast.create_variable_node("y"), rhs = rhs })
    mock_free_vars.find = spy.new(function() return { "x" } end)

    local result, err = classification.analyze(eq)
    assert.is_nil(err)
    assert.are.same({
      dim = 2,
      form = "explicit",
      series = {
        { kind = "function", ast = eq, independent_vars = { "x" }, dependent_vars = { "y" } },
      },
    }, result)
  end)

  it("classifies x^2 + y^2 = 1 as implicit", function()
    local eq = ast_node("equality", { lhs = "x^2+y^2", rhs = "1" })
    mock_free_vars.find = spy.new(function() return { "x", "y" } end)

    local result, err = classification.analyze(eq)
    assert.is_nil(err)
    assert.are.same({
      dim = 2,
      form = "implicit",
      series = {
        { kind = "function", ast = eq, independent_vars = { "x", "y" }, dependent_vars = {} },
      },
    }, result)
  end)
end)
