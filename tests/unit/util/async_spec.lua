-- tests/unit/util/async_spec.lua
-- Unit tests for tungsten.util.async.run_job

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local async = require 'tungsten.util.async'
local state = require 'tungsten.state'
local config = require 'tungsten.config'

local function clear_active_jobs()
  for k in pairs(state.active_jobs) do
    state.active_jobs[k] = nil
  end
end

local function wait_for(fn, timeout)
  timeout = timeout or 2000
  local start = vim.loop.now()
  vim.wait(timeout, function()
    return fn() or vim.loop.now() - start > timeout
  end, 10)
end

describe('tungsten.util.async.run_job', function()
  before_each(function()
    clear_active_jobs()
  end)

  it('runs command successfully and captures stdout', function()
    local result
    local handle = async.run_job({'sh','-c','sleep 0.1; printf ok'}, {
      expr_key = 'ok',
      timeout = 1000,
      on_exit = function(code, out, err)
        result = {code=code, out=out, err=err}
      end,
    })
    assert.truthy(state.active_jobs[handle.id])
    wait_for(function() return result end)
    assert.are.equal(0, result.code)
    assert.are.equal('ok', result.out)
    assert.are.equal('', result.err)
    assert.falsy(state.active_jobs[handle.id])
  end)

  it('handles non-zero exit code and stderr', function()
    local result
    local handle = async.run_job({'sh','-c','printf fail 1>&2; exit 3'}, {
      expr_key = 'fail',
      timeout = 1000,
      on_exit = function(code, out, err)
        result = {code=code, out=out, err=err}
      end,
    })
    wait_for(function() return result end)
    assert.are.equal(3, result.code)
    assert.are.equal('', result.out)
    assert.are.equal('fail', result.err)
    assert.falsy(state.active_jobs[handle.id])
  end)

  it('terminates on timeout', function()
    local result
    local handle = async.run_job({'sh','-c','sleep 2'}, {
      expr_key = 'timeout',
      timeout = 100,
      on_exit = function(code,out,err)
        result = {code=code,out=out,err=err}
      end,
    })
    wait_for(function() return result end, 1000)
    assert.is_true(result.code ~= 0)
    assert.falsy(state.active_jobs[handle.id])
  end)

  it('can cancel a running job', function()
    local result
    local handle = async.run_job({'sh','-c','sleep 2'}, {
      expr_key = 'cancel',
      timeout = 1000,
      on_exit = function(code,out,err)
        result = {code=code,out=out,err=err}
      end,
    })
    vim.defer_fn(function()
      async.cancel_process(handle)
    end, 100)
    wait_for(function() return result end, 1000)
    assert.is_true(result.code ~= 0)
    assert.falsy(state.active_jobs[handle.id])
  end)

  it('is_process_active reflects running state', function()
    local done = false
    local handle = async.run_job({'sh','-c','sleep 0.3'}, {
      expr_key='active',
      timeout=1000,
      on_exit=function() done = true end,
    })
    assert.is_true(async.is_process_active(handle))
    vim.defer_fn(function() end, 50)
    vim.wait(50)
    assert.is_true(async.is_process_active(handle))
    wait_for(function() return done end, 1000)
    assert.is_false(async.is_process_active(handle))
  end)
end)

