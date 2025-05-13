local render = require("tungsten.core.render").render

-- minimal handlers table just for this spec
local H = {
  ["number"] = function(n) return tostring(n.value) end,
  ["binary"] = function(n, r)
    return r(n.left) .. n.operator .. r(n.right)
  end,
}

describe("core.render.render", function()
  it("walks the AST with custom handlers", function()
    local ast = { type = "binary", operator = "*",
                  left = { type="number", value=5 },
                  right= { type="number", value=6 } }

    assert.are.equal("5*6", render(ast, H))
  end)
end)

