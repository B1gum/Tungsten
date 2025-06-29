-- lua/tungsten/util/async.lua

local state = require('tungsten.state')
local logger = require('tungsten.util.logger')
local config = require('tungsten.config')

local M = {}

function M.run_job(cmd, expr_key, on_complete)
  local stdout_chunks, stderr_chunks = {}, {}
  local job_id, job_timer

  local timeout_ms = config.wolfram_timeout_ms or 10000

  local function finalize(exit_code)
    if job_timer then
      if job_timer.stop then job_timer:stop() end
      if job_timer.close then job_timer:close() end
      job_timer = nil
    end

    if job_id and state.active_jobs[job_id] then
      state.active_jobs[job_id] = nil
    end

    on_complete(
      exit_code,
      table.concat(stdout_chunks, '\n'):gsub('^%s*(.-)%s*$', '%1'),
      table.concat(stderr_chunks, '\n'):gsub('^%s*(.-)%s*$', '%1')
    )
  end

  job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then for _, chunk in ipairs(data) do table.insert(stdout_chunks, chunk) end end
    end,
    on_stderr = function(_, data)
      if data then for _, chunk in ipairs(data) do table.insert(stderr_chunks, chunk) end end
    end,
    on_exit = function(_, code) finalize(code) end,
  })

  if not job_id or job_id <= 0 then
    local reason = "Unknown error"
    if job_id == 0 then
        reason = "Invalid arguments"
    elseif job_id == -1 then
        reason = "Command not found"
    end
    finalize(job_id)
    return nil
  end

  state.active_jobs[job_id] = {
    bufnr = vim.api.nvim_get_current_buf(),
    expr_key = expr_key,
    code_sent = table.concat(cmd, ' '),
    start_time = vim.loop.now()
  }

  job_timer = vim.loop.new_timer()
  if not job_timer then
      logger.notify("TungstenSolve: Failed to create job timer.", logger.levels.ERROR, { title = "Tungsten Error" })
      return job_id 
  end
  
  job_timer:start(timeout_ms, 0, function()
    if state.active_jobs[job_id] then
      logger.notify(
        string.format("Tungsten: Wolframscript job %d timed out after %d ms.", job_id, timeout_ms),
        logger.levels.WARN,
        { title = "Tungsten" }
      )
      vim.fn.jobstop(job_id)
    end
  end)

  return job_id
end

return M
