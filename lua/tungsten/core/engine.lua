-- engine.lua
-- Manages the interaction with the Wolfram Engine via wolframscript
----------------------------------------------------------------------------------

local parse = require("tungsten.core.parser").parse
local cg = require("tungsten.backends.wolfram")
local toWolfram = cg.to_string
local config = require("tungsten.config") -- User configurations
local state = require("tungsten.state")   -- Plugin's runtime state
local logger = require "tungsten.util.logger"

local M = {} -- Module table to hold functions

-- Generates a cache key from an AST and numeric mode.
local function get_cache_key(ast_or_code_string, numeric)
  local code_str
  if type(ast_or_code_string) == "table" then
    -- If it's an AST, convert to Wolfram code string
    local ok, result = pcall(toWolfram, ast_or_code_string)
    if not ok then
      return "error::ast_conversion_failed"
    end
    code_str = result
  elseif type(ast_or_code_string) == "string" then
    -- If it's already a code string
    code_str = ast_or_code_string
  else
    return "error::invalid_cache_key_input"
  end
  return code_str .. (numeric and "::numeric" or "::symbolic")
end


--- Asynchronously evaluates a math expression represented by an AST.
-- @param ast The abstract syntax tree produced by the LPeg parser.
-- @param numeric (boolean) If true, the expression is evaluated in numeric mode.
-- @param callback A function that receives the evaluated output (string) as its first argument,
--                 and an error message (string) as its second argument if an error occurred.
function M.evaluate_async(ast, numeric, callback)
  assert(type(callback) == "function", "evaluate_async expects a callback function")

  local initial_wolfram_code
  local pcall_ok, pcall_result = pcall(toWolfram, ast)
  if not pcall_ok then
    local err_msg = "Error converting AST to Wolfram code: " .. tostring(pcall_result)
    logger.notify("Tungsten: " .. err_msg, logger.levels.ERROR, { title = "Tungsten Error" })
    callback(nil, err_msg)
    return
  end
  initial_wolfram_code = pcall_result

  local expr_key = get_cache_key(initial_wolfram_code, numeric)

  -- 1. Check cache first (if enabled by config)
  -- If config.cache_enabled is nil (not set by user), we default to true.
  local use_cache = (config.cache_enabled == nil) or (config.cache_enabled == true)

  if use_cache then
    if state.cache[expr_key] then
      -- Notifying that result is from cache
      logger.notify("Tungsten: Result from cache.", logger.levels.INFO, { title = "Tungsten" }) -- Corrected
      if config.debug then
        logger.notify("Tungsten Debug: Cache hit for key: " .. expr_key, logger.levels.INFO, { title = "Tungsten Debug" }) -- Corrected
      end
      callback(state.cache[expr_key], nil)
      return
    end
  end

  -- 2. Check active jobs
  for job_id_running, job_info in pairs(state.active_jobs) do
    if job_info.expr_key == expr_key then
      local notify_msg = "Tungsten: Evaluation already in progress for this expression."
      if config.debug then
        notify_msg = ("Tungsten: Evaluation already in progress for key: '%s' (Job ID: %s)"):format(expr_key, tostring(job_id_running))
      end
      logger.notify(notify_msg, logger.levels.INFO, { title = "Tungsten" })
      -- Do not proceed to start a new job. The first job will eventually populate the cache (if enabled)
      -- and its callback will be triggered. Subsequent identical calls that hit this check
      -- effectively wait for the first one to complete and then benefit from the cache on their next attempt.
      -- To make this more sophisticated, you could queue callbacks for the same expr_key.
      return
    end
  end

  local code_to_execute = initial_wolfram_code
  if config.numeric_mode or numeric then
    code_to_execute = "N[" .. code_to_execute .. "]"
  end

  local wolfram_path = config.wolfram_path or "wolframscript"
  local current_bufnr = vim.api.nvim_get_current_buf()

  local stdout_chunks = {}
  local stderr_chunks = {}
  local job_id

  local job_options = {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data, _)
      if data then
        for _, chunk in ipairs(data) do table.insert(stdout_chunks, chunk) end
      end
    end,
    on_stderr = function(_, data, _)
      if data then
        for _, chunk in ipairs(data) do table.insert(stderr_chunks, chunk) end
      end
    end,
    on_exit = function(_, exit_code, _)
      local final_stdout = table.concat(stdout_chunks, "\n"):gsub("^%s*(.-)%s*$", "%1")
      local final_stderr = table.concat(stderr_chunks, "\n"):gsub("^%s*(.-)%s*$", "%1")

      if job_id and state.active_jobs[job_id] then
        state.active_jobs[job_id] = nil
        if config.debug then
          logger.notify("Tungsten: Job " .. job_id .. " finished and removed from active jobs.", logger.levels.INFO, { title = "Tungsten Debug" })
        end
      end

      if exit_code == 0 then
        if final_stderr ~= "" and config.debug then
          logger.notify("Tungsten (Job " .. job_id .. " stderr): " .. final_stderr, logger.levels.WARN, { title = "Tungsten Debug" })
        end
        if use_cache then
          state.cache[expr_key] = final_stdout
          if config.debug then
            logger.notify("Tungsten: Result for key '" .. expr_key .. "' stored in cache.", logger.levels.INFO, { title = "Tungsten Debug" })
          end
        end
        callback(final_stdout, nil)
      else

        local err_msg = ("WolframScript (Job %s) exited with code %d"):format(tostring(job_id or "N/A"), exit_code)
        if final_stderr ~= "" then
          err_msg = err_msg .. "\nStderr: " .. final_stderr
        elseif final_stdout ~= "" then
          err_msg = err_msg .. "\nStdout (potentially error): " .. final_stdout
        end
        logger.notify("Tungsten: " .. err_msg, logger.levels.ERROR, { title = "Tungsten Error" })
        callback(nil, err_msg)
      end
    end,
  }

  job_id = vim.fn.jobstart({ wolfram_path, "-code", code_to_execute }, job_options)

  if not job_id or job_id <= 0 then -- job_id can be 0 or negative for errors
    local err_msg = "Failed to start WolframScript job."
    if job_id == 0 then
      err_msg = err_msg .. " (Reason: Invalid arguments to jobstart)"
    elseif job_id == -1 then
      err_msg = err_msg .. " (Reason: Command '" .. wolfram_path .. "' not found - is wolframscript in your PATH?)"
    else
      err_msg = err_msg .. " (Reason: jobstart returned " .. tostring(job_id) .. ")"
    end
    logger.notify("Tungsten: " .. err_msg, logger.levels.ERROR, { title = "Tungsten Error" })
    callback(nil, err_msg)
  else
    state.active_jobs[job_id] = {
      bufnr = current_bufnr,
      expr_key = expr_key,
      code_sent = code_to_execute,
      start_time = vim.loop.now(),
    }
    if config.debug then
      logger.notify(("Tungsten: Started WolframScript job %d for key '%s' with code: %s"):format(job_id, expr_key, code_to_execute), logger.levels.INFO, { title = "Tungsten Debug" })
    end
  end
end

function M.run_async(input, numeric, callback)
  assert(type(callback) == "function", "run_async expects a callback function")
  local ok, ast = pcall(parse, input)
  if not ok or ast == nil then
    local err_msg = "Parse error: " .. tostring(ast or "nil AST")
    logger.notify("Tungsten: " .. err_msg, logger.levels.ERROR, { title = "Tungsten Error" })
    callback(nil, err_msg)
    return
  end
  M.evaluate_async(ast, numeric, callback)
end

M.parse = parse

function M.clear_cache()
  state.cache = {}
  logger.notify("Tungsten: Cache cleared.", logger.levels.INFO, { title = "Tungsten" })
end

function M.view_active_jobs()
  if vim.tbl_isempty(state.active_jobs) then
    logger.notify("Tungsten: No active jobs.", logger.levels.INFO, { title = "Tungsten" })
    return
  end
  local report = { "Active Tungsten Jobs:" }
  for id, info in pairs(state.active_jobs) do
    table.insert(report, ("- ID: %s, Key: %s, Buf: %s, Code: %s"):format(
      tostring(id),
      info.expr_key,
      tostring(info.bufnr),
      info.code_sent:sub(1, 50) .. (info.code_sent:len() > 50 and "..." or "")
    ))
  end
  -- For multiline notifications, it's better to print or use a floating window.
  -- vim.notify might truncate or not display newlines well.
  -- For simplicity here, we still use vim.notify.
  logger.notify(table.concat(report, "\n"), logger.levels.INFO, { title = "Tungsten Active Jobs" })
end

function M.get_cache_size()
    local count = 0
    for _ in pairs(state.cache) do
        count = count + 1
    end
    logger.notify("Tungsten: Cache size: " .. count .. " entries.", logger.levels.INFO, { title = "Tungsten" })
    return count
end

return M

