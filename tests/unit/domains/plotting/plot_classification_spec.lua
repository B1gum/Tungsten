local classification = require("tungsten.domains.plotting.classification")

describe("plot classification", function()
  it("classifies single-variable expressions as 2D explicit", function()
    local ast = { type = "variable", name = "x" }
    local result = classification.analyze(ast)
    assert.are.same(2, result.dim)
    assert.are.same("explicit", result.form)
  end)

  it("classifies two-variable expressions as 3D explicit", function()
    local ast = {
      type = "binary_op",
      operator = "+",
      left = { type = "variable", name = "x" },
      right = { type = "variable", name = "y" },
    }
    local result = classification.analyze(ast)
    assert.are.same(3, result.dim)
    assert.are.same("explicit", result.form)
  end)
end)

