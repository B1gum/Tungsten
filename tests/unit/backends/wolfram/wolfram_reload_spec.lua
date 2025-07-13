local wolfram_backend
local mock_utils = require "tests.helpers.mock_utils"

local function clear_module()
  mock_utils.reset_modules({"tungsten.backends.wolfram"})
  wolfram_backend = require "tungsten.backends.wolfram"
end

describe("wolfram.reload_handlers", function()
  before_each(function()
    clear_module()
  end)

  it("can be called multiple times without altering output", function()
    wolfram_backend.reload_handlers()
    local ast = { type = "number", value = 42 }
    local first = wolfram_backend.ast_to_wolfram(ast)

    wolfram_backend.reload_handlers()
    local second = wolfram_backend.ast_to_wolfram(ast)

    assert.are.equal(first, second)
  end)
end)

