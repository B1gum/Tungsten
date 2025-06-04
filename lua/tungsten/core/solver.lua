-- lua/tungsten/core/solver.lua
-- Handles equation solving logic for Tungsten.

local parser = require "tungsten.core.parser"
local wolfram_backend = require "tungsten.backends.wolfram"
local evaluator = require "tungsten.core.engine"
local config = require "tungsten.config"
local logger = require "tungsten.util.logger"
local state = require "tungsten.state"

local M = {}

local function split_string(input, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(input, "([^" .. sep .. "]+)") do
    table.insert(t, str:match("^%s*(.-)%s*$"))
  end
  return t
end

function M.parse_solve_input(text)
  local sep_pos = text:find(";", 1, true)

  if not sep_pos then
    logger.notify("TungstenSolve: Invalid format. Missing semicolon separator. Expected '<EQUATIONS>; <VARS_TO_SOLVE>'.", logger.levels.ERROR, { title = "Tungsten Error" })
    return nil
  end

  local equations_block_latex = text:sub(1, sep_pos - 1):match("^%s*(.-)%s*$")
  local variables_block_str = text:sub(sep_pos + 1):match("^%s*(.-)%s*$")

  if equations_block_latex == "" then
    logger.notify("TungstenSolve: Equations part cannot be empty.", logger.levels.ERROR, { title = "Tungsten Error" })
    return nil
  end
  if variables_block_str == "" then
    logger.notify("TungstenSolve: Variables to solve cannot be empty.", logger.levels.ERROR, { title = "Tungsten Error" })
    return nil
  end

  local individual_equation_latex_strs = split_string(equations_block_latex, ",")
  local individual_variable_strs = split_string(variables_block_str, ",")

  if #individual_equation_latex_strs == 0 then
    logger.notify("TungstenSolve: No equations found after splitting.", logger.levels.ERROR, { title = "Tungsten Error"})
    return nil
  end
  if #individual_variable_strs == 0 then
    logger.notify("TungstenSolve: No variables found after splitting.", logger.levels.ERROR, { title = "Tungsten Error"})
    return nil
  end

  local wolfram_eq_strs = {}
  for i, eq_latex in ipairs(individual_equation_latex_strs) do
    local ok_eq, ast_eq_or_err = pcall(parser.parse, eq_latex)
    if not ok_eq or not ast_eq_or_err then
      logger.notify("TungstenSolve: Parse error for equation #" .. i .. " ('" .. eq_latex .. "') – " .. tostring(ast_eq_or_err), logger.levels.ERROR, { title = "Tungsten Error" })
      return nil
    end
    local ast_eq = ast_eq_or_err

    if not ast_eq or ast_eq.type ~= "equation" then
      logger.notify("TungstenSolve: Input for equation #" .. i .. " ('" .. eq_latex .. "') is not a valid equation structure after parsing.", logger.levels.ERROR, { title = "Tungsten Error" })
      return nil
    end

    local ok_wolfram, wolfram_eq_str_or_err = pcall(wolfram_backend.to_string, ast_eq)

    if not ok_wolfram or not wolfram_eq_str_or_err or type(wolfram_eq_str_or_err) ~= "string" then
      logger.notify("TungstenSolve: Failed to convert AST to Wolfram string for equation #" .. i .. " ('" .. eq_latex .. "'): " .. tostring(wolfram_eq_str_or_err), logger.levels.ERROR, { title = "Tungsten Error" })
      return nil
    end

    local wolfram_eq_str_before_subst = wolfram_eq_str_or_err
    local wolfram_eq_str_after_subst = evaluator.substitute_persistent_vars(wolfram_eq_str_before_subst, state.persistent_variables)

    table.insert(wolfram_eq_strs, wolfram_eq_str_after_subst)
  end

  local parsed_variable_names = {}
  for i, var_str in ipairs(individual_variable_strs) do
    local var_ast_check_ok, var_ast_or_error = pcall(parser.parse, var_str)
    if not var_ast_check_ok or not var_ast_or_error or var_ast_or_error.type ~= "variable" then
      logger.notify("TungstenSolve: Variable to solve #" .. i .. " ('" .. var_str .. "') is not a valid simple variable.", logger.levels.ERROR, { title = "Tungsten Error" })
      return nil
    end
    table.insert(parsed_variable_names, wolfram_backend.to_string(var_ast_or_error))
  end

  return {
    equation_strs = wolfram_eq_strs,
    variable_strs = parsed_variable_names,
    is_system = #individual_equation_latex_strs > 1 or #individual_variable_strs > 1
  }
end

function M.solve_equation_async(text, callback)
  assert(callback, "solve_equation_async expects a callback to be provided")

  local parsed_input = M.parse_solve_input(text)
  if not parsed_input then
    callback(nil, "Failed to parse solve input.")
    return
  end

  local equations_wolfram_list = "{" .. table.concat(parsed_input.equation_strs, ", ") .. "}"
  local variables_wolfram_list = "{" .. table.concat(parsed_input.variable_strs, ", ") .. "}"
  local wolfram_command = string.format("Solve[%s, %s]", equations_wolfram_list, variables_wolfram_list)

  if config.debug then
    logger.notify("TungstenSolve: Wolfram command: " .. wolfram_command, logger.levels.DEBUG, {title = "Tungsten Debug"})
  end

   wolfram_command = "ToString[TeXForm[" .. wolfram_command .. "], CharacterEncoding -> \"UTF8\"]"

  local job_id
  local stdout_chunks = {}
  local stderr_chunks = {}
  local job_timer = nil
  local job_completed_or_stopped = false

  local function cleanup_job_state()
    job_completed_or_stopped = true
    if state.active_jobs and job_id and state.active_jobs[job_id] then
      state.active_jobs[job_id] = nil
      if config.debug then
          logger.notify("Tungsten Debug: Job " .. (job_id or "N/A") .. " state cleaned and removed from active jobs.", logger.levels.DEBUG, { title = "Tungsten Debug" })
      end
    end
    if job_timer then
      if job_timer.stop then job_timer:stop() end
      if job_timer.close then job_timer:close() end
      job_timer = nil
    end
  end

  local function handle_exit(_, exit_code_arg, _)
    if job_completed_or_stopped then
        if config.debug then
            logger.notify("Tungsten Debug: handle_exit called for job " .. (job_id or "N/A") .. " but job_completed_or_stopped is true. Ignoring.", logger.levels.DEBUG, {title = "Tungsten Debug"})
        end
        return
    end
    cleanup_job_state()

    local temp_final_stdout = table.concat(stdout_chunks, ""):match("^%s*(.-)%s*$")
    local temp_final_stderr = table.concat(stderr_chunks, ""):match("^%s*(.-)%s*$")

    local final_stdout = temp_final_stdout
    local final_stderr = temp_final_stderr

    if exit_code_arg == 0 then
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
                local clean_var = var:match("^%s*(.-)%s*$")
                local clean_val = val:match("^%s*(.-)%s*$")
                formatted_solutions_map[clean_var] = clean_val
            end
        end

        if not vim.tbl_isempty(formatted_solutions_map) then
            if #parsed_input.variable_strs == 1 and formatted_solutions_map[parsed_input.variable_strs[1]] then
                callback(formatted_solutions_map[parsed_input.variable_strs[1]], nil)
            else
                local solution_strings = {}
                for _, var_name in ipairs(parsed_input.variable_strs) do
                    if formatted_solutions_map[var_name] then
                        table.insert(solution_strings, var_name .. " = " .. formatted_solutions_map[var_name])
                    else
                        table.insert(solution_strings, var_name .. " = Not Found")
                    end
                end
                callback(table.concat(solution_strings, ", "), nil)
            end
        else
          if #parsed_input.variable_strs == 1 and not parsed_input.is_system then
            local single_var_val = raw_solution_str:match("{{%s*" .. parsed_input.variable_strs[1] .. "%s*->%s*(.-)%s*}}")
            if single_var_val then
                 callback(single_var_val:match("^%s*(.-)%s*$"), nil)
            else
                logger.notify("TungstenSolve: Could not parse single solution from Wolfram output (fallback): " .. raw_solution_str, logger.levels.WARN, { title = "Tungsten Solve" })
                callback(raw_solution_str, nil)
            end
          else
            logger.notify("TungstenSolve: Could not parse system solution from Wolfram output (general fallback): " .. raw_solution_str, logger.levels.WARN, { title = "Tungsten Solve" })
            callback(raw_solution_str, nil)
          end
        end
      end
    else
      local err_msg = string.format("TungstenSolve: WolframScript (Job %s) error. Code: %s\nStderr: %s\nStdout: %s",
        tostring(job_id or "N/A"), tostring(exit_code_arg), final_stderr, final_stdout)
      logger.notify(err_msg, logger.levels.ERROR, { title = "Tungsten Error" })
      callback(nil, err_msg)
    end
  end

  local job_options = {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data, _) if data then for _, chunk in ipairs(data) do table.insert(stdout_chunks, chunk) end end end,
    on_stderr = function(_, data, _) if data then for _, chunk in ipairs(data) do table.insert(stderr_chunks, chunk) end end end,
    on_exit = handle_exit,
  }

  job_id = vim.fn.jobstart({ config.wolfram_path, "-code", wolfram_command }, job_options)

  if not job_id or job_id <= 0 then
    local err_msg = "TungstenSolve: Failed to start WolframScript job for solving."
    if job_id == 0 then err_msg = err_msg .. " (Reason: Invalid arguments)" end
    if job_id == -1 then err_msg = err_msg .. " (Reason: Command not found)" end
    logger.notify(err_msg, logger.levels.ERROR, { title = "Tungsten Error" })
    callback(nil, err_msg)
  else
    if state.active_jobs then
      state.active_jobs[job_id] = {
        bufnr = vim.api.nvim_get_current_buf(),
        expr_key = "solve:" .. text,
        code_sent = wolfram_command,
        start_time = vim.loop.now(),
      }
    end

    job_timer = vim.loop.new_timer()
    if not job_timer then
        logger.notify("TungstenSolve: Failed to create job timer.", logger.levels.ERROR, {title = "Tungsten Error"})
    else
        job_timer:start(config.wolfram_timeout_ms or 10000, 0, function()
            if job_completed_or_stopped or not job_timer then return end

            local job_info = state.active_jobs and job_id and state.active_jobs[job_id]
            if job_info then
                if vim.loop.now() - job_info.start_time >= (config.wolfram_timeout_ms or 10000) then
                    logger.notify(("TungstenSolve: Wolframscript job %d timed out. Attempting to stop."):format(job_id), logger.levels.WARN, { title = "Tungsten" })
                    vim.schedule(function()
                        if not job_completed_or_stopped and state.active_jobs and job_id and state.active_jobs[job_id] then
                            vim.fn.jobstop(job_id)
                        end
                    end)
                end
            end
            if job_timer and job_timer.close then job_timer:close(); job_timer = nil; end
        end)
    end
  end
end

return M
