-- engine.lua
-- Manages the interaction with the Wolfram Engine via wolframscript
----------------------------------------------------------------------------------

local wolfram_codegen = require "tungsten.backends.wolfram"
local config = require "tungsten.config"
local state = require "tungsten.state"
local async = require "tungsten.util.async"
local logger = require "tungsten.util.logger"

local lpeg = require "lpeg"

local P, Cs = lpeg.P, lpeg.Cs

local M = {}

local function build_var_pattern(vars)
  local names = vim.tbl_keys(vars)
  table.sort(names, function(a, b)
    return #a > #b
  end)

  local patterns = {}
  local word = lpeg.R("AZ", "az", "09") + P("_")

  for _, name in ipairs(names) do
    local value = vars[name]
    local p = (-lpeg.B(word)) * P(name) * -word / ("(" .. value .. ")")
    table.insert(patterns, p)
  end

  local combined = patterns[1]
  for i = 2, #patterns do
    combined = combined + patterns[i]
  end

  return combined
end

function M.substitute_persistent_vars(code_string, variables_map)
  if not variables_map or vim.tbl_isempty(variables_map) then
    return code_string
  end

  local var_pattern = build_var_pattern(variables_map)
  local replacer = Cs((var_pattern + P(1)) ^ 0)

  local changed
  repeat
    local replaced = replacer:match(code_string)
    changed = replaced ~= code_string
    code_string = replaced
  until not changed

  return code_string
end


local function get_cache_key(code_string, numeric)
  return code_string .. (numeric and "::numeric" or "::symbolic")
end
M.get_cache_key = get_cache_key

function M.evaluate_async(ast, numeric, callback)
  assert(type(callback) == "function", "evaluate_async expects a callback function")

  local initial_wolfram_code
  local pcall_ok, pcall_result = pcall(wolfram_codegen.to_string, ast)
  if not pcall_ok or pcall_result == nil then
    local err_msg = "Error converting AST to Wolfram code: " .. tostring(pcall_result)
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
      vim.schedule(function() callback(state.cache[expr_key], nil) end)
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

  code_to_execute = "ToString[TeXForm[" .. code_to_execute .. "], CharacterEncoding -> \"UTF8\"]"

  async.run_job({ config.wolfram_path, "-code", code_to_execute }, {
    expr_key = expr_key,
    on_exit = function(exit_code, final_stdout, final_stderr)
    if exit_code == 0 then
      if final_stderr ~= "" and config.debug then
        logger.notify("Tungsten Debug (stderr): " .. final_stderr, logger.levels.DEBUG, { title = "Tungsten Debug" })
      end
      if use_cache then
        state.cache[expr_key] = final_stdout
        if config.debug then
          logger.notify("Tungsten: Result for key '" .. expr_key .. "' stored in cache.", logger.levels.INFO, { title = "Tungsten Debug" })
        end
      end
      callback(final_stdout, nil)
    else
      local err_msg = ("WolframScript exited with code %d"):format(exit_code)
      if final_stderr ~= "" then
        err_msg = err_msg .. "\nStderr: " .. final_stderr
      elseif final_stdout ~= "" then
        err_msg = err_msg .. "\nStdout (potentially error): " .. final_stdout
      end
      callback(nil, err_msg)
    end
  end
  })
end


function M.run_async(input, numeric, callback)
  assert(type(callback) == "function", "run_async expects a callback function")
  local parser_module = require "tungsten.core.parser"

  local ok, ast = pcall(parser_module.parse, input)
  if not ok or ast == nil then
    local err_msg = "Parse error: " .. tostring(ast or "nil AST")
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
