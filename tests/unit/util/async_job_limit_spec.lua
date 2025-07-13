-- tests/unit/util/async_job_limit_spec.lua
-- Verifies that async.run_job respects config.max_jobs

local async = require "tungsten.util.async"
local state = require "tungsten.state"
local config = require "tungsten.config"

local function clear_active_jobs()
  for k in pairs(state.active_jobs) do
    state.active_jobs[k] = nil
  end
end

local wait_for = require "tests.helpers.wait".wait_for

local function count(tbl)
  local n = 0
  for _ in pairs(tbl) do n = n + 1 end
  return n
end

describe('tungsten.util.async.run_job job limit', function()
  before_each(function()
    clear_active_jobs()
  end)

  it('limits the number of concurrent jobs', function()
    local original_max = config.max_jobs
    config.max_jobs = 2

    local results = {}
    local counts = {}

    async.run_job({'sh','-c','sleep 0.2; echo a'}, {
      expr_key = 'a',
      timeout = 1000,
      on_exit = function() results[#results+1] = 'a' end,
    })
    async.run_job({'sh','-c','sleep 0.2; echo b'}, {
      expr_key = 'b',
      timeout = 1000,
      on_exit = function() results[#results+1] = 'b' end,
    })
    async.run_job({'sh','-c','sleep 0.2; echo c'}, {
      expr_key = 'c',
      timeout = 1000,
      on_exit = function() results[#results+1] = 'c' end,
    })

    wait_for(function()
      counts[#counts+1] = count(state.active_jobs)
      return #results == 3
    end, 3000)

    local max_seen = 0
    for _, v in ipairs(counts) do
      if v > max_seen then max_seen = v end
    end

    assert.is_true(max_seen <= 2)
    assert.are.equal(3, #results)

    config.max_jobs = original_max
  end)
end)
