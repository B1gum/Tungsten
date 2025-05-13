local parser = require("tungsten.core.parser")

describe("core.parser.parse", function()
  it("parses a simple addition into an AST", function()
    local ast = parser.parse("1+2")

    assert.is_table(ast)
    assert.are.equal("binary", ast.type)
    assert.are.equal("+",      ast.operator)
    assert.are.equal(1,        ast.left.value)
    assert.are.equal(2,        ast.right.value)
  end)
end)

