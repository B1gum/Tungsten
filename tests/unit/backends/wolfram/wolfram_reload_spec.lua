local wolfram_backend

local function clear_module()
  package.loaded['tungsten.backends.wolfram'] = nil
  wolfram_backend = require 'tungsten.backends.wolfram'
end

describe("wolfram.reload_handlers", function()
  before_each(function()
    clear_module()
  end)

  it("can be called multiple times without altering output", function()
    wolfram_backend.reload_handlers()
    local ast = { type = "number", value = 42 }
    local first = wolfram_backend.to_string(ast)

    wolfram_backend.reload_handlers()
    local second = wolfram_backend.to_string(ast)

    assert.are.equal(first, second)
  end)
end)

