-- engine.lua
-- Manages the interaction with the Wolfram Engine via wolframscript
----------------------------------------------------------------------------------

local parse = require("tungsten.core.parser").parse
local cg = require("tungsten.backends.wolfram")
local toWolfram = cg.to_string
local config = require("tungsten.config")

local M = {} -- Module table to hold functions

--- Asynchronously evaluates a math expression represented by an AST.
-- @param ast The abstract syntax tree produced by the LPeg parser.
-- @param numeric (boolean) If true, the expression is evaluated in numeric mode.
-- @param callback A function that receives the evaluated output (string) as its first argument,
--                 and an error message (string) as its second argument if an error occurred.
function M.evaluate_async(ast, numeric, callback)
  assert(type(callback) == "function", "evaluate_async expects a callback function")

  -- Convert the AST to a WolframScript code string.
  local code_to_execute
  local ok, result = pcall(toWolfram, ast)
  if not ok then
    vim.notify("Tungsten: Error converting AST to Wolfram code - " .. tostring(result), vim.log.levels.ERROR)
    callback(nil, "Error converting AST to Wolfram code: " .. tostring(result))
    return
  end
  code_to_execute = result

  if config.numeric_mode or numeric then
    code_to_execute = "N[" .. code_to_execute .. "]"
  end

  -- Get the WolframScript command path from config (defaulting to "wolframscript" if not set)
  local wolfram_path = config.wolfram_path or "wolframscript"

  local stdout_chunks = {}
  local stderr_chunks = {}

  local job_options = {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data, _)
      -- data is a table of strings, nil on EOF
      if data then
        for _, chunk in ipairs(data) do
          table.insert(stdout_chunks, chunk)
        end
      end
    end,
    on_stderr = function(_, data, _)
      -- data is a table of strings, nil on EOF
      if data then
        for _, chunk in ipairs(data) do
          table.insert(stderr_chunks, chunk)
        end
      end
    end,
    on_exit = function(_, exit_code, _)
      local final_stdout = table.concat(stdout_chunks, "\n"):gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace
      local final_stderr = table.concat(stderr_chunks, "\n"):gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace

      if exit_code == 0 then
        if final_stderr ~= "" and config.debug then -- Log stderr even on success if debug is on
            vim.notify("Tungsten (stderr): " .. final_stderr, vim.log.levels.WARN)
        end
        callback(final_stdout, nil)
      else
        local err_msg = ("WolframScript exited with code %d"):format(exit_code)
        if final_stderr ~= "" then
          err_msg = err_msg .. "\nStderr: " .. final_stderr
        elseif final_stdout ~= "" then -- Sometimes errors might go to stdout
          err_msg = err_msg .. "\nStdout: " .. final_stdout
        end
        vim.notify("Tungsten: " .. err_msg, vim.log.levels.ERROR)
        callback(nil, err_msg)
      end
    end,
  }

  -- Start the job asynchronously.
  local job_id = vim.fn.jobstart({ wolfram_path, "-code", code_to_execute }, job_options)

  if not job_id or job_id == 0 or job_id == -1 then
    local err_msg = "Failed to start WolframScript job."
    if job_id == 0 then
        err_msg = err_msg .. " (Reason: Invalid arguments)"
    elseif job_id == -1 then
        err_msg = err_msg .. " (Reason: Command not found - is wolframscript in your PATH?)"
    end
    vim.notify("Tungsten: " .. err_msg, vim.log.levels.ERROR)
    callback(nil, err_msg)
  elseif config.debug then
    vim.notify(("Tungsten: Started WolframScript job %d with code: %s"):format(job_id, code_to_execute), vim.log.levels.INFO)
  end
end

function M.run_async(input, numeric, callback)
  assert(type(callback) == "function", "run_async expects a callback function")
  local ok, ast = pcall(parse, input)
  if not ok or ast == nil then
    local err_msg = "Parse error: " .. tostring(ast)
    vim.notify("Tungsten: " .. err_msg, vim.log.levels.ERROR)
    callback(nil, err_msg) -- Pass error to callback
    return
  end
  -- The callback will handle the result.
  M.evaluate_async(ast, numeric, callback)
end

-- Optional: re‑export the parser so callers can still get the AST
M.parse = parse

return M
