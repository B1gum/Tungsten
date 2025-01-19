--------------------------------------------------------------------------------
-- async.lua
-- Handles asynchronous integration with WolframScript
--------------------------------------------------------------------------------

-- 1) setup
--------------------------------------------------------------------------------
local io_utils = require("tungsten.utils.io_utils").debug_print
local cache = require("tungsten.cache")

local M = {}

local function fix_sqrt_tex(str)  -- Helper-function that replaces \text{Sqrt} with \sqrt to conform with LaTex-syntax
  local out = str:gsub("\\text%{Sqrt%}", "\\sqrt")
  return out
end


-- Hash function for building a unique key
local function build_key(cmd_args)
  -- If your `cmd_args` is something like { "wolframscript", "-code", "ToString[...]"} just flatten it into a single string:
  local joined = table.concat(cmd_args, "|")
  return vim.fn.sha256(joined)
end


-- 2) Define function that runs WolframScript asynchronously
--------------------------------------------------------------------------------
local function run_wolframscript_async(cmd, callback)
  -- cmd is an array like { "wolframscript", "-code", "some Wolfram code" }
  local cache_key = build_key(cmd)
  
  -- 1) Check the cache first
  local cached_result = cache.get(cache_key)
  if cached_result then
    io_utils("Cache HIT => returning cached result")
    callback(cached_result, nil) -- Return immediately
    return
  end

  io_utils("Cache MISS => launching wolframscript job, cmd => " .. table.concat(cmd, " "))
  
  local job_id = vim.fn.jobstart(cmd, {               -- Initializes an asynchronous job to run thd cmd
    stdout_buffered = true,                           -- Buffers the output such that all output is collected before being passed to callback
    on_stdout = function(_, data, _)
      if not data then                                -- If no data is present, then
        callback(nil, "No data from WolframScript")   -- Return an error
        return
      end
      local result = table.concat(data, "\n")
      result = result:gsub("[%z\1-\31]", "")          -- Remove control-characters and non-printable characters from the output
      result = fix_sqrt_tex(result)                   -- Call the fix_sqrt_tex-function
      io_utils("on_stdout => " .. result)    -- (Optionally) prints the cleaned and formatted result
      callback(result, nil)                           -- Returns the callback with the result and "nil" for the error
    end,
    on_stderr = function(_, errdata, _)
      if errdata and #errdata > 0 then                -- If there is any error data, then
        io_utils("on_stderr => " .. table.concat(errdata, " "))  -- Print the error data
        callback(nil, table.concat(errdata, " "))     -- Returns the callback with the error data and "nil" for the result
      end
    end,
    on_exit = function(_, exit_code, _)
      io_utils("on_exit => code = " .. exit_code)  -- (Optionally) prints the exit-code
      if exit_code ~= 0 then                                -- If exit-code is not 0 (indicating failure), then
        callback(nil, "WolframScript exited with code " .. exit_code)   -- Returns the callback wirh the exit code and "nil" for the result
      end
    end
  })

  if job_id <= 0 then                                     -- If job failed to start, then
    callback(nil, "Failed to start wolframscript job.")   -- Returns the callback with the error message and "nil" for the result
  else
    io_utils("Started job_id => " .. job_id)     -- Else (Optionally) print the job_id
  end
end

M.run_wolframscript_async = run_wolframscript_async       -- Attach run_wolframscript_async to M




-- 3) Asynchronous evaluation
--------------------------------------------------------------------------------
function M.run_evaluation_async(equation, numeric, callback)
  local expr = string.format('ToExpression["%s"]', equation)  -- Converts the LaTex-formattex expression into WolframScript using ToExpression
  local wrapped = numeric and string.format("ToString[N[%s], TeXForm]", expr) -- Sets if evaluation is numeric or symbolic
                        or string.format("ToString[%s, TeXForm]", expr)

  local cmd = { "wolframscript", "-code", wrapped, "-format", "OutputForm" }  -- Formats the command
  run_wolframscript_async(cmd, callback)  -- Runs the command
end




-- 4) Asynchronous simplification
--------------------------------------------------------------------------------
function M.run_simplify_async(equation, numeric, callback)
  local expr = string.format('ToExpression["%s"]', equation)  -- Converts the LaTex-formattex expression into WolframScript using ToExpression
  local simplifyWrapper = numeric and string.format("ToString[N[FullSimplify[%s]], TeXForm]", expr) -- Sets if simplification is numeric or symbolic
                                     or string.format("ToString[FullSimplify[%s], TeXForm]", expr)

  local cmd = { "wolframscript", "-code", simplifyWrapper, "-format", "OutputForm" }  -- Formats the command
  run_wolframscript_async(cmd, callback)  -- Runs the command
end




-- 5) Asynchronous solving
--------------------------------------------------------------------------------
function M.run_solve_async(equation, variable, callback)
  local solveCommand = string.format('NSolve[%s, %s]', equation, variable)    -- Formats the solve-command
  local wrapped = string.format("ToString[%s, TeXForm]", solveCommand)        -- Converts result into LaTex

  local cmd = { "wolframscript", "-code", wrapped, "-format", "OutputForm" }  -- Sets up command
  run_wolframscript_async(cmd, callback)  -- Runs the command
end




-- 6) Asynchronous system solving
--------------------------------------------------------------------------------
function M.run_solve_system_async(equations, variables, callback)
  local eqsStr = "{ " .. table.concat(equations, ", ") .. " }"                -- Formats the equations
  local varsStr = "{ " .. table.concat(variables, ", ") .. " }"               -- Formats the variables
  local solveCommand = string.format('NSolve[%s, %s]', eqsStr, varsStr)       -- Formats the command
  local wrapped = string.format("ToString[%s, TeXForm]", solveCommand)        -- Convert result into LaTex

  local cmd = { "wolframscript", "-code", wrapped, "-format", "OutputForm" }  -- Sets up command
  run_wolframscript_async(cmd, callback)  -- Runs the command
end




-- 7) Asynchronous plotting
--------------------------------------------------------------------------------
function M.run_plot_async(wolfram_code, plotfile, callback)
  local code = string.format('Export["%s", %s]', plotfile, wolfram_code)    -- Sets up code for exporting the created plot as a .pdf

  local cmd = { "wolframscript", "-code", code}                             -- Sets up the WolframScript-command
  io_utils("run_plot_async cmd => " .. table.concat(cmd, " "))     -- (Optionally) prints the command to be passed to the engine

  local job_id = vim.fn.jobstart(cmd, {                                     -- Initiate asynchronous job with same logic as the general implementation
    stdout_buffered = true,
    on_stdout = function(_, data, _)
      if data and #data > 0 then
        io_utils("on_stdout => " .. table.concat(data, " "))
      end
    end,
    on_stderr = function(_, errdata, _)
      if errdata and #errdata > 0 then
        io_utils("on_stderr => " .. table.concat(errdata, " "))
      end
    end,
    on_exit = function(_, exit_code, _)
      io_utils("run_plot_async on_exit => code = " .. exit_code)
      if exit_code == 0 then
        callback(nil)
      else
        callback("WolframScript exited with code " .. exit_code)
      end
    end
  })

  if job_id <= 0 then
    callback("Failed to start wolframscript plot job.")
  else
    io_utils("Started plot job_id => " .. job_id)
  end
end

return M
