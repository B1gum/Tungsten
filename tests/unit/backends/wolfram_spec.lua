local to_string = require("tungsten.backends.wolfram").to_string
local ast       = require("tungsten.core.ast")

describe("backends.wolfram.to_string", function()
  it("serialises an addition AST to Wolfram syntax", function()
    local n = ast.make_bin("+",
        { type = "number", value = 3 },
        { type = "number", value = 4 })

    assert.are.equal("3+4", to_string(n))
  end)
end)
