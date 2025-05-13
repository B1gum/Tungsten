local ast = require("tungsten.core.ast")

describe("core.ast.make_bin", function()
  it("constructs a binary node with operator and children", function()
    local left  = { type = "number", value = 1 }
    local right = { type = "number", value = 2 }

    local n = ast.make_bin("+", left, right)

    assert.are.same("binary", n.type)
    assert.are.same("+",      n.operator)
    assert.are.same(left,     n.left)
    assert.are.same(right,    n.right)
  end)
end)

