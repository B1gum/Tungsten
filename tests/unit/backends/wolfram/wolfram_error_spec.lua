-- tests/unit/backends/wolfram/wolfram_error_spec.lua
-- Unit tests for tungsten.util.wolfram_error.parse_wolfram_error

local error_parser = require 'tungsten.backends.wolfram.wolfram_error'

describe("util.wolfram_error.parse_wolfram_error", function()
  it("recognizes Name::tag style errors", function()
    local err = error_parser.parse_wolfram_error("Solve::nsmet: no solution")
    assert.are.equal("Solve::nsmet: no solution", err)
  end)

  it("parses Message[Name::tag, \"...\"] format", function()
    local err = error_parser.parse_wolfram_error('Message[Solve::nsmet, "no solution"]')
    assert.are.equal("Solve::nsmet: no solution", err)
  end)

  it("returns nil for unrecognized output", function()
    local err = error_parser.parse_wolfram_error("Some unrelated output")
    assert.is_nil(err)
  end)
end)


