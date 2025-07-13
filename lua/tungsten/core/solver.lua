-- lua/tungsten/core/solver.lua

local evaluator = require "tungsten.core.engine"
local config = require "tungsten.config"
local logger = require "tungsten.util.logger"
local state = require "tungsten.state"
local async = require "tungsten.util.async"
local solution_helper = require "tungsten.backends.wolfram.wolfram_solution"
local error_parser = require "tungsten.backends.wolfram.wolfram_error"

local M = {}

function M.solve_equation_async(eq_strs, vars, is_system, callback)
  assert(callback and type(eq_strs) == "table" and type(vars) == "table", "solve_equation_async expects tables and a callback")
  if #eq_strs == 0 then callback(nil, "No equations provided to solver."); return end
  if #vars == 0 then callback(nil, "No variables provided to solver."); return end

  local final_eqs = {}
  for _, eq in ipairs(eq_strs) do final_eqs[#final_eqs+1] = evaluator.substitute_persistent_vars(eq, state.persistent_variables) end

  local eq_list = "{" .. table.concat(final_eqs, ", ") .. "}"
  local var_list = "{" .. table.concat(vars, ", ") .. "}"
  local wolfram_command = string.format("Solve[%s, %s]", eq_list, var_list)
  logger.debug("Tungsten Debug", "TungstenSolve: Wolfram command: " .. wolfram_command)
  wolfram_command = "ToString[TeXForm[" .. wolfram_command .. "], CharacterEncoding -> \"UTF8\"]"

  local cache_key = "solve:" .. eq_list .. "_for_" .. var_list

  async.run_job({ config.wolfram_path, "-code", wolfram_command }, {
    cache_key = cache_key,
    on_exit = function(code, stdout, stderr)
    if code == 0 then
      local out = stdout
      if stdout == "" and stderr ~= "" then
        logger.warn("Tungsten Solve", "TungstenSolve: Wolfram returned result via stderr: " .. stderr)
        out = stderr
      elseif stdout == "" and stderr == "" then
        logger.warn("Tungsten Solve", "TungstenSolve: Wolfram returned empty stdout and stderr. No solution found or equation not solvable.")
      end
      local result = solution_helper.parse_wolfram_solution(out, vars, is_system)
      if result.ok then callback(result.formatted, nil) else callback(nil, result.reason) end
    else
      local parsed_err = error_parser.parse_wolfram_error(stderr)
      if parsed_err then
        callback(nil, parsed_err)
        return
      end

      local reason = code == -1 and "Command not found" or code == 0 and "Invalid arguments" or "exited with code " .. tostring(code)
      local err = code < 1 and string.format("TungstenSolve: Failed to start WolframScript job for solving. (Reason: %s)", reason)
        or string.format("TungstenSolve: WolframScript (Job N/A) error. Code: %s\nStderr: %s\nStdout: %s", tostring(code), stderr, stdout)
      callback(nil, err)
    end
  end
  })
end


return M

