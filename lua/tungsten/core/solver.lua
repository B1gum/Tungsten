-- lua/tungsten/core/solver.lua
-- Handles equation solving logic for Tungsten.

local parser = require "tungsten.core.parser"
local wolfram_backend = require "tungsten.backends.wolfram"
local evaluator = require "tungsten.core.engine"
local config = require "tungsten.config"
local logger = require "tungsten.util.logger"
local state = require "tungsten.state"
local string_util = require "tungsten.util.string"
local async = require "tungsten.util.async"

local M = {}

function M.solve_equation_async(eq_wolfram_strs_table, var_wolfram_strs_table, is_system_solve, callback)
  assert(callback, "solve_equation_async expects a callback to be provided")
  assert(type(eq_wolfram_strs_table) == "table", "eq_wolfram_strs_table must be a table")
  assert(type(var_wolfram_strs_table) == "table", "var_wolfram_strs_table must be a table")

  if #eq_wolfram_strs_table == 0 then
    callback(nil, "No equations provided to solver.")
    return
  end
  if #var_wolfram_strs_table == 0 then
    callback(nil, "No variables provided to solver.")
    return
  end

  local final_eq_strs = {}
  for _, eq_str in ipairs(eq_wolfram_strs_table) do
      table.insert(final_eq_strs, evaluator.substitute_persistent_vars(eq_str, state.persistent_variables))
  end

  local equations_wolfram_list = "{" .. table.concat(final_eq_strs, ", ") .. "}"
  local variables_wolfram_list = "{" .. table.concat(var_wolfram_strs_table, ", ") .. "}"
  local wolfram_command = string.format("Solve[%s, %s]", equations_wolfram_list, variables_wolfram_list)

  if config.debug then
    logger.notify("TungstenSolve: Wolfram command: " .. wolfram_command, logger.levels.DEBUG, {title = "Tungsten Debug"})
  end

  wolfram_command = "ToString[TeXForm[" .. wolfram_command .. "], CharacterEncoding -> \"UTF8\"]"

  local expr_key = "solve:" .. equations_wolfram_list .. "_for_" .. variables_wolfram_list

  async.run_job(
    { config.wolfram_path, "-code", wolfram_command },
    expr_key,
    function(exit_code, final_stdout, final_stderr)
      if exit_code == 0 then
        local solution_output_to_parse = final_stdout
        if final_stdout == "" and final_stderr ~= "" then
          logger.notify("TungstenSolve: Wolfram returned result via stderr: " .. final_stderr, logger.levels.WARN, { title = "Tungsten Solve" })
          solution_output_to_parse = final_stderr
        end

        if solution_output_to_parse == "" and final_stderr == "" then
          logger.notify("TungstenSolve: Wolfram returned empty stdout and stderr. No solution found or equation not solvable.", logger.levels.WARN, { title = "Tungsten Solve" })
          callback("No solution found", nil)
        else
          local formatted_solutions_map = {}
          local raw_solution_str = solution_output_to_parse
          local temp_solution_output = raw_solution_str:match("^%s*{{(.*)}}%s*$") or raw_solution_str:match("^%s*{(.*)}%s*$") or raw_solution_str

          for var_val_pair in string.gmatch(temp_solution_output, "([^,{}]+%s*->%s*[^,{}]+)") do
              local var, val = var_val_pair:match("(.+)%s*->%s*(.+)")
              if var and val then
                  local clean_var = string_util.trim(var)
                  local clean_val = string_util.trim(val)
                  formatted_solutions_map[clean_var] = clean_val
              end
          end

          if not vim.tbl_isempty(formatted_solutions_map) then
              if not is_system_solve and #var_wolfram_strs_table == 1 and formatted_solutions_map[var_wolfram_strs_table[1]] then
                  callback(formatted_solutions_map[var_wolfram_strs_table[1]], nil)
              else
                  local solution_strings = {}
                  for _, var_name in ipairs(var_wolfram_strs_table) do
                      if formatted_solutions_map[var_name] then
                          table.insert(solution_strings, var_name .. " = " .. formatted_solutions_map[var_name])
                      else
                          table.insert(solution_strings, var_name .. " = (Not explicitly solved)")
                      end
                  end
                  callback(table.concat(solution_strings, ", "), nil)
              end
          else
            if not is_system_solve and #var_wolfram_strs_table == 1 then
              local single_var_name_for_match = vim.pesc(var_wolfram_strs_table[1])
              local single_var_val_match = raw_solution_str:match("{{%s*" .. single_var_name_for_match .. "%s*->%s*(.-)%s*}}") or
                                           raw_solution_str:match("{%s*" .. single_var_name_for_match .. "%s*->%s*(.-)%s*}")

              if single_var_val_match then
                callback(string_util.trim(single_var_val_match), nil)
              else
                  logger.notify("TungstenSolve: Could not parse single solution from Wolfram output (fallback): " .. raw_solution_str, logger.levels.WARN, { title = "Tungsten Solve" })
                  callback(raw_solution_str, nil)
              end
            else
              logger.notify("TungstenSolve: Could not parse solution from Wolfram output (general fallback): " .. raw_solution_str, logger.levels.WARN, { title = "Tungsten Solve" })
              callback(raw_solution_str, nil)
            end
          end
        end
      else
        local err_msg = string.format("TungstenSolve: WolframScript error. Code: %s\nStderr: %s\nStdout: %s",
          tostring(exit_code), final_stderr, final_stdout)
        logger.notify(err_msg, logger.levels.ERROR, { title = "Tungsten Error" })
        callback(nil, err_msg)
      end
    end
  )
end

return M
