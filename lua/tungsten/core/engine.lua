-- engine.lua
-- Manages the interaction with the Wolfram Engine via wolframscript
----------------------------------------------------------------------------------

local cg = require "tungsten.backends.wolfram"
local config = require "tungsten.config"
local state = require "tungsten.state"

local M = {}

function M.substitute_persistent_vars(code_string, variables_map)
  if not variables_map or vim.tbl_isempty(variables_map) then
    return code_string
  end

  local sorted_var_names = {}
  for var_name, _ in pairs(variables_map) do
    table.insert(sorted_var_names, var_name)
  end
  table.sort(sorted_var_names, function(a, b)
    return #a > #b
  end)

  local current_code = code_string
  local changed_in_a_full_pass

  repeat
    changed_in_a_full_pass = false
    for _, var_name in ipairs(sorted_var_names) do
      local var_wolfram_def = variables_map[var_name]
      local pattern_to_find = vim.pesc(var_name)

      local temp_code_before_this_var_substitution = current_code
      local new_parts = {}
      local search_start_index = 1

      while true do
        local s, e = string.find(current_code, pattern_to_find, search_start_index, true)

        if not s then
          table.insert(new_parts, string.sub(current_code, search_start_index))
          break
        end

        local pre_char = (s == 1) and "" or string.sub(current_code, s - 1, s - 1)
        local post_char = (e == #current_code) and "" or string.sub(current_code, e + 1, e + 1)

        local is_pre_boundary = (s == 1) or (not pre_char:match("%w"))
        local is_post_boundary = (e == #current_code) or (not post_char:match("%w"))

        table.insert(new_parts, string.sub(current_code, search_start_index, s - 1))

        if is_pre_boundary and is_post_boundary then
          table.insert(new_parts, "(" .. var_wolfram_def .. ")")
        else
          table.insert(new_parts, string.sub(current_code, s, e))
        end
        search_start_index = e + 1
      end
      current_code = table.concat(new_parts)

      if current_code ~= temp_code_before_this_var_substitution then
        changed_in_a_full_pass = true
      end
    end
  until not changed_in_a_full_pass

  return current_code
end


local function get_cache_key(code_string, numeric)
  return code_string .. (numeric and "::numeric" or "::symbolic")
end
M.get_cache_key = get_cache_key

function M.evaluate_async(ast, numeric, callback)
  assert(type(callback) == "function", "evaluate_async expects a callback function")
  local logger = require "tungsten.util.logger"

  local initial_wolfram_code
  local pcall_ok, pcall_result = pcall(cg.to_string, ast)
  if not pcall_ok then
    local err_msg = "Error converting AST to Wolfram code: " .. tostring(pcall_result)
    logger.notify("Tungsten: " .. err_msg, logger.levels.ERROR, { title = "Tungsten Error" })
    callback(nil, err_msg)
    return
  end
  initial_wolfram_code = pcall_result

  local code_with_vars_substituted = M.substitute_persistent_vars(initial_wolfram_code, state.persistent_variables)
  if config.debug then
    if code_with_vars_substituted ~= initial_wolfram_code then
      logger.notify("Tungsten Debug: Code after persistent variable substitution: " .. code_with_vars_substituted, logger.levels.DEBUG, { title = "Tungsten Debug" })
    else
      logger.notify("Tungsten Debug: No persistent variable substitutions made.", logger.levels.DEBUG, { title = "Tungsten Debug" })
    end
  end

  local expr_key = get_cache_key(code_with_vars_substituted, numeric)
  local use_cache = (config.cache_enabled == nil) or (config.cache_enabled == true)

  if use_cache then
    if state.cache[expr_key] then
      logger.notify("Tungsten: Result from cache.", logger.levels.INFO, { title = "Tungsten" })
      if config.debug then
        logger.notify("Tungsten Debug: Cache hit for key: " .. expr_key, logger.levels.INFO, { title = "Tungsten Debug" })
      end
      callback(state.cache[expr_key], nil)
      return
    end
  end

  for job_id_running, job_info in pairs(state.active_jobs) do
    if job_info.expr_key == expr_key then
      local notify_msg = "Tungsten: Evaluation already in progress for this expression."
      if config.debug then
        notify_msg = ("Tungsten: Evaluation already in progress for key: '%s' (Job ID: %s)"):format(expr_key, tostring(job_id_running))
      end
      logger.notify(notify_msg, logger.levels.INFO, { title = "Tungsten" })
      return
    end
  end

  local code_to_execute = code_with_vars_substituted
  if config.numeric_mode or numeric then
    code_to_execute = "N[" .. code_to_execute .. "]"
  end

  local wolfram_path = config.wolfram_path or "wolframscript"
  local stdout_chunks = {}
  local stderr_chunks = {}
  local job_id
  local job_timer

  local function handle_stdout(_, data, _)
    if data then
      for _, chunk in ipairs(data) do table.insert(stdout_chunks, chunk) end
    end
  end

  local function handle_stderr(_, data, _)
    if data then
      for _, chunk in ipairs(data) do table.insert(stderr_chunks, chunk) end
    end
  end

  local function handle_exit(_, exit_code, _)
    if job_timer then
        if job_timer.stop then job_timer:stop() end
        if job_timer.close then job_timer:close() end
        job_timer = nil
    end

    local final_stdout = table.concat(stdout_chunks, "\n"):gsub("^%s*(.-)%s*$", "%1")
    local final_stderr = table.concat(stderr_chunks, "\n"):gsub("^%s*(.-)%s*$", "%1")

    if job_id and state.active_jobs[job_id] then
      state.active_jobs[job_id] = nil
      if config.debug then
        logger.notify("Tungsten Debug: Job " .. job_id .. " finished and removed from active jobs.", logger.levels.DEBUG, { title = "Tungsten Debug" })
      end
    end

    if exit_code == 0 then
      if final_stderr ~= "" and config.debug then
        logger.notify("Tungsten Debug (Job " .. job_id .. " stderr): " .. final_stderr, logger.levels.DEBUG, { title = "Tungsten Debug" })
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
  end

  local job_options = {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = handle_stdout,
    on_stderr = handle_stderr,
    on_exit = handle_exit,
  }

  job_id = vim.fn.jobstart({ wolfram_path, "-code", code_to_execute }, job_options)

  if not job_id or job_id <= 0 then
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
    local current_job_start_time = vim.loop.now()
    state.active_jobs[job_id] = {
      bufnr = vim.api.nvim_get_current_buf(),
      expr_key = expr_key,
      code_sent = code_to_execute,
      start_time = current_job_start_time,
    }
    if config.debug then
      logger.notify(("Tungsten: Started WolframScript job %d for key '%s' with code: %s"):format(job_id, expr_key, code_to_execute), logger.levels.INFO, { title = "Tungsten Debug" })
    end

    local timeout_ms = config.wolfram_timeout_ms or 10000
    job_timer = vim.loop.new_timer()
    job_timer:start(timeout_ms, 0, function()
      if job_id and state.active_jobs[job_id] then
        if vim.loop.now() - state.active_jobs[job_id].start_time >= timeout_ms then
          logger.notify(("Tungsten: Wolframscript job %d timed out after %d ms."):format(job_id, timeout_ms), logger.levels.WARN, { title = "Tungsten" })
        end
      end
      if job_timer and job_timer.close then job_timer:close(); job_timer = nil; end
    end)
  end
end

function M.run_async(input, numeric, callback)
  assert(type(callback) == "function", "run_async expects a callback function")
  local logger = require "tungsten.util.logger"
  local parser_module = require "tungsten.core.parser"

  local ok, ast = pcall(parser_module.parse, input)
  if not ok or ast == nil then
    local err_msg = "Parse error: " .. tostring(ast or "nil AST")
    logger.notify("Tungsten: " .. err_msg, logger.levels.ERROR, { title = "Tungsten Error" })
    callback(nil, err_msg)
    return
  end
  M.evaluate_async(ast, numeric, callback)
end

M.parse = function(...)
  return require("tungsten.core.parser").parse(...)
end

function M.clear_cache()
  state.cache = {}
  require("tungsten.util.logger").notify("Tungsten: Cache cleared.", require("tungsten.util.logger").levels.INFO, { title = "Tungsten" })
end

function M.view_active_jobs()
  local logger = require "tungsten.util.logger"
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
  logger.notify(table.concat(report, "\n"), logger.levels.INFO, { title = "Tungsten Active Jobs" })
end

function M.get_cache_size()
    local count = 0
    for _ in pairs(state.cache) do
        count = count + 1
    end
    require("tungsten.util.logger").notify("Tungsten: Cache size: " .. count .. " entries.", require("tungsten.util.logger").levels.INFO, { title = "Tungsten" })
    return count
end

return M
