-- tests/engine_spec.lua
local engine = require("tungsten.core.engine")

-- ── stub out jobstart so it invokes `on_stdout` synchronously
vim.fn.jobstart = function(_cmd, opts)
  if opts and opts.on_stdout then
    -- immediately simulate WolframScript returning "42"
    opts.on_stdout(nil, { "42" }, nil)
  end
  return 1
end

describe("core.engine.run_async", function()

  it("notifies on parse failure", function()
    -- hijack vim.notify
    local last_notify
    vim.notify = function(msg) last_notify = msg end

    engine.run_async("!@#", false)
    -- parse errors fire notify synchronously
    assert.matches("Parse error", last_notify)
  end)
end)

