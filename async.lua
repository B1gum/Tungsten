-- Handles asynchronous interactions with WolframScript.

local utils = require("tungsten.utils")

local M = {}

-- Helper function to parse Wolfram output
local function parse_result(raw_result)
  -- Implement parsing logic if needed. For now, return raw_result
  return raw_result
end

local function fix_sqrt_tex(str)
  -- Replace "\text{Sqrt}" with "\sqrt"
  -- Optionally change parentheses to braces if you want strictly "\sqrt{(x+1)^2}" etc.
  local out = str:gsub("\\text%{Sqrt%}", "\\sqrt")
  -- Possibly also do parentheses => braces if you prefer:
  -- out = out:gsub("%(", "{"):gsub("%)", "}")
  return out
end

-- Run WolframScript asynchronously
local function run_wolframscript_async(cmd, callback)
  utils.debug_print("run_wolframscript_async cmd => " .. table.concat(cmd, " "))

  local job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data, _)
      if not data then
        callback(nil, "No data from WolframScript")
        return
      end
      local result = table.concat(data, "\n")
      result = result:gsub("[%z\1-\31]", "")
      result = fix_sqrt_tex(result)
      utils.debug_print("on_stdout => " .. result)
      callback(result, nil)
    end,
    on_stderr = function(_, errdata, _)
      if errdata and #errdata > 0 then
        utils.debug_print("on_stderr => " .. table.concat(errdata, " "))
        callback(nil, table.concat(errdata, " "))
      end
    end,
    on_exit = function(_, exit_code, _)
      utils.debug_print("on_exit => code = " .. exit_code)
      if exit_code ~= 0 then
        callback(nil, "WolframScript exited with code " .. exit_code)
      end
    end
  })

  if job_id <= 0 then
    callback(nil, "Failed to start wolframscript job.")
  else
    utils.debug_print("Started job_id => " .. job_id)
  end
end

M.run_wolframscript_async = run_wolframscript_async



-- Asynchronous evaluation
function M.run_evaluation_async(equation, numeric, callback)
  local expr = string.format('ToExpression["%s"]', equation)
  local wrapped = numeric and string.format("ToString[N[%s], TeXForm]", expr)
                        or string.format("ToString[%s, TeXForm]", expr)

  local cmd = { "wolframscript", "-code", wrapped, "-format", "OutputForm" }
  run_wolframscript_async(cmd, callback)
end

-- Asynchronous simplification
function M.run_simplify_async(equation, numeric, callback)
  local expr = string.format('ToExpression["%s"]', equation)
  local simplifyWrapper = numeric and string.format("ToString[N[FullSimplify[%s]], TeXForm]", expr)
                                     or string.format("ToString[FullSimplify[%s], TeXForm]", expr)

  local cmd = { "wolframscript", "-code", simplifyWrapper, "-format", "OutputForm" }
  run_wolframscript_async(cmd, callback)
end

-- Asynchronous solving
function M.run_solve_async(equation, variable, callback)
  local solveCommand = string.format('NSolve[%s, %s]', equation, variable)
  local wrapped = string.format("ToString[%s, TeXForm]", solveCommand)

  local cmd = { "wolframscript", "-code", wrapped, "-format", "OutputForm" }
  run_wolframscript_async(cmd, callback)
end

-- Asynchronous system solving
function M.run_solve_system_async(equations, variables, callback)
  local eqsStr = "{ " .. table.concat(equations, ", ") .. " }"
  local varsStr = "{ " .. table.concat(variables, ", ") .. " }"
  local solveCommand = string.format('NSolve[%s, %s]', eqsStr, varsStr)
  local wrapped = string.format("ToString[%s, TeXForm]", solveCommand)

  local cmd = { "wolframscript", "-code", wrapped, "-format", "OutputForm" }
  run_wolframscript_async(cmd, callback)
end

-- Asynchronous plotting
function M.run_plot_async(wolfram_code, plotfile, callback)
  local code = string.format([[
Export["%s", %s]
]], plotfile, wolfram_code)

  local cmd = { "wolframscript", "-code", code }
  utils.debug_print("run_plot_async cmd => " .. table.concat(cmd, " "))

  local job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    on_stdout = function(_, data, _)
      if data and #data > 0 then
        utils.debug_print("on_stdout => " .. table.concat(data, " "))
      end
    end,
    on_stderr = function(_, errdata, _)
      if errdata and #errdata > 0 then
        utils.debug_print("on_stderr => " .. table.concat(errdata, " "))
      end
    end,
    on_exit = function(_, exit_code, _)
      utils.debug_print("run_plot_async on_exit => code = " .. exit_code)
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
    utils.debug_print("Started plot job_id => " .. job_id)
  end
end

return M
