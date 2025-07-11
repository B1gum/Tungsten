-- lua/tungsten/util/async.lua
-- Utilities for spawning external processes asynchronously.

local state = require('tungsten.state')
local logger = require('tungsten.util.logger')
local config = require('tungsten.config')

local M = {}

local function spawn_process(cmd, opts)
  opts = opts or {}
  local expr_key = opts.expr_key
  local on_exit = opts.on_exit or opts.on_complete
  local timeout = opts.timeout or config.wolfram_timeout_ms or 10000

  local stdout_chunks, stderr_chunks = {}, {}

  local completed = false
  local handle

  local function finalize(code)
    if completed then return end
    completed = true

    if handle and handle.id and state.active_jobs[handle.id] then
      state.active_jobs[handle.id] = nil
    end

    if on_exit then
      on_exit(
        code,
        table.concat(stdout_chunks, '\n'):gsub('^%s*(.-)%s*$', '%1'),
        table.concat(stderr_chunks, '\n'):gsub('^%s*(.-)%s*$', '%1')
      )
    end
end

  local Job = require('plenary.job')
  local job = Job:new{
    command = cmd[1],
    args = vim.list_slice(cmd, 2),
    enable_recording = true,
    on_stdout = function(_, line)
      if line then table.insert(stdout_chunks, line) end
    end,
    on_stderr = function(_, line)
      if line then table.insert(stderr_chunks, line) end
    end,
    on_exit = function(j, code)
      stdout_chunks = j:result()
      stderr_chunks = j:stderr_result()
      finalize(code)
    end,
  }
  job:start()
  handle = {
    id = job.pid,
    _job = job,
  }
  function handle.cancel()
    if not completed then
      job:shutdown()
      finalize(-1)
    end
  end
  function handle.is_active()
    return not completed
  end

  if timeout then
    vim.defer_fn(function()
      if not completed then
        logger.notify(
          string.format(
            'Tungsten: Wolframscript job %d timed out after %d ms.',
            handle.id, timeout
          ),
          logger.levels.WARN,
          { title = 'Tungsten' }
        )
        handle.cancel()
      end
    end, timeout)
  end

  state.active_jobs[handle.id] = {
    bufnr = vim.api.nvim_get_current_buf(),
    expr_key = expr_key,
    code_sent = table.concat(cmd, ' '),
    start_time = vim.loop.now(),
  }

  return handle
end

M.run_job = spawn_process

function M.cancel_process(handle)
  if handle and handle.cancel then
    handle.cancel()
  end
end

function M.is_process_active(handle)
  return handle and handle.is_active and handle.is_active() or false
end

return M

