-- core/comands.lua
-- Defines core user-facing Neovim commands
-----------------------------------------------

local parser    = require "tungsten.core.parser"
local solver = require "tungsten.core.solver"
local evaluator = require "tungsten.core.engine"
local selection = require "tungsten.util.selection"
local insert_result_util = require "tungsten.util.insert_result"
local config    = require "tungsten.config"
local logger    = require "tungsten.util.logger"
local error_handler = require "tungsten.util.error_handler"
local state     = require "tungsten.state"
local wolfram_backend = require "tungsten.backends.wolfram"
local vim_inspect = require "vim.inspect"
local string_util = require "tungsten.util.string"
local cmd_utils = require "tungsten.util.commands"

local function tungsten_eval_command(_)
  local ast, _, err = cmd_utils.parse_selected_latex("expression")
  if err then
    error_handler.notify_error("Eval", err)
    return
  end
  if not ast then return end

  local use_numeric_mode = config.numeric_mode

  evaluator.evaluate_async(ast, use_numeric_mode, function(result, err2)
    if err2 then
      error_handler.notify_error("Eval", err2)
      return
    end
    if result == nil or result == "" then
      return
    end
    insert_result_util.insert_result(result)
  end)
end

local function define_persistent_variable_command(_)
  local selected_text = selection.get_visual_selection()
  if selected_text == "" or selected_text == nil then
    error_handler.notify_error("DefineVar", "No text selected for variable definition.")
    return
  end

  local op_to_use_str = nil
  local op_start_pos = nil

  local op_double_start = selected_text:find(":=", 1, true)
  local op_single_start = selected_text:find("=", 1, true)

  if op_double_start then
    op_to_use_str = ":="
    op_start_pos = op_double_start
    logger.debug("Tungsten Debug", "Tungsten Debug: Operator ':=' found at pos " .. tostring(op_start_pos))
  elseif op_single_start then
    op_to_use_str = "="
    op_start_pos = op_single_start
    logger.debug("Tungsten Debug", "Tungsten Debug: Operator '=' found at pos " .. tostring(op_start_pos))
  end

  if not op_start_pos then
    error_handler.notify_error("DefineVar", "No assignment operator ('=' or ':=') found in selection.")
    return
  end

  local var_name_end_index = op_start_pos - 1
  if var_name_end_index < 0 then var_name_end_index = 0 end

  local raw_part1 = selected_text:sub(1, var_name_end_index)
  logger.debug("Tungsten Debug", "Tungsten Debug: Raw parts[1] before trim: '" .. raw_part1 .. "' (op_start_pos was " .. tostring(op_start_pos) .. ")")
  local var_name_str = string_util.trim(raw_part1)

  local rhs_start_index = op_start_pos + #op_to_use_str
  local raw_part2 = selected_text:sub(rhs_start_index)
  logger.debug("Tungsten Debug", "Tungsten Debug: Raw parts[2] before trim: '" .. raw_part2 .. "' (rhs_start_index was " .. tostring(rhs_start_index) .. ", operator was '" .. op_to_use_str .. "')")
  local rhs_latex_str = string_util.trim(raw_part2)

  if var_name_str == "" then
    error_handler.notify_error("DefineVar", "Variable name cannot be empty.")
    return
  end

  if rhs_latex_str == "" then
    error_handler.notify_error("DefineVar", "Variable definition (LaTeX) cannot be empty.")
    return
  end

  logger.debug("Tungsten Debug", "Tungsten Debug: Defining variable '" .. var_name_str .. "' with LaTeX RHS: '" .. rhs_latex_str .. "'")

  local parse_ok, definition_ast_or_err = pcall(parser.parse, rhs_latex_str)
  if not parse_ok or not definition_ast_or_err then
    error_handler.notify_error("DefineVar", "Failed to parse LaTeX definition for '" .. var_name_str .. "': " .. tostring(definition_ast_or_err))
    return
  end
  local definition_ast = definition_ast_or_err

  logger.debug("Tungsten Debug", "Tungsten Debug: AST for '" ..var_name_str.. "' before to_string: " .. vim_inspect(definition_ast))

  local conversion_ok, wolfram_definition_str_or_err = pcall(wolfram_backend.to_string, definition_ast)

  logger.debug("Tungsten Debug", "Tungsten Debug: pcall result for to_string: conversion_ok=" .. tostring(conversion_ok) .. ", returned_value=" .. vim_inspect(wolfram_definition_str_or_err))

  if not conversion_ok or not wolfram_definition_str_or_err or type(wolfram_definition_str_or_err) ~= "string" then
    error_handler.notify_error("DefineVar", "Failed to convert definition AST to wolfram string for '" .. var_name_str .. "': " .. tostring(wolfram_definition_str_or_err))
    return
  end
  local wolfram_definition_str = wolfram_definition_str_or_err

  logger.debug("Tungsten Debug", "Tungsten Debug: Storing variable '" .. var_name_str .. "' with Wolfram string: '" .. wolfram_definition_str .. "'")

  state.persistent_variables = state.persistent_variables or {}
  state.persistent_variables[var_name_str] = wolfram_definition_str

  logger.info("Tungsten", "Tungsten: Defined persistent variable '" .. var_name_str .. "' as '" .. wolfram_definition_str .. "'.")
end


local function tungsten_solve_command(_)
  local initial_start_pos = vim.fn.getpos("'<")
  local initial_end_pos = vim.fn.getpos("'>")

  if initial_start_pos[2] == 0 and initial_start_pos[3] == 0 and initial_end_pos[2] == 0 and initial_end_pos[3] == 0 then
    error_handler.notify_error("Solve", "No equation selected.")
    return
  end

  local parsed_ast_top, equation_text, parse_err = cmd_utils.parse_selected_latex("equation")
  if parse_err then
    error_handler.notify_error("Solve", parse_err)
    return
  end
  if not parsed_ast_top then return end

  local eq_ast
  if parsed_ast_top.type == "solve_system_equations_capture" then
    if parsed_ast_top.equations and #parsed_ast_top.equations == 1 then
      eq_ast = parsed_ast_top.equations[1]
      logger.debug("Tungsten Debug", "TungstenSolve: Extracted single equation from system capture.")
    else
      error_handler.notify_error("Solve", "Parsed as system with not exactly one equation.")
      return
    end
  else
    eq_ast = parsed_ast_top
  end


  local is_valid_equation_structure = false
  if eq_ast and ( (eq_ast.type == "binary" and eq_ast.operator == "=") or eq_ast.type == "EquationRule" or eq_ast.type == "equation" ) then
      is_valid_equation_structure = true
  end

  if not is_valid_equation_structure then
    error_handler.notify_error("Solve", "Selected text is not a valid single equation.")
    return
  end

  vim.ui.input({ prompt = "Enter variable to solve for (e.g., x):" }, function(var_input_str)
    if var_input_str == nil or var_input_str == "" then
      error_handler.notify_error("Solve", "No variable entered.")
      return
    end
    local trimmed_var_name = string_util.trim(var_input_str)
    if trimmed_var_name == "" then
      error_handler.notify_error("Solve", "Variable cannot be empty.")
      return
    end

    local var_parse_ok, var_ast = pcall(parser.parse, trimmed_var_name)
    if not var_parse_ok or not var_ast or var_ast.type ~= "variable" then
      error_handler.notify_error("Solve", "Invalid variable: '" .. trimmed_var_name .. "'.")
      return
    end

    local eq_wolfram_ok, eq_wolfram_str = pcall(wolfram_backend.to_string, eq_ast)
    if not eq_wolfram_ok or not eq_wolfram_str then
      error_handler.notify_error("Solve", "Failed to convert equation.")
      return
    end
    local var_wolfram_ok, var_wolfram_str = pcall(wolfram_backend.to_string, var_ast)
    if not var_wolfram_ok or not var_wolfram_str then
      error_handler.notify_error("Solve", "Failed to convert variable.")
      return
    end

    solver.solve_equation_async({eq_wolfram_str}, {var_wolfram_str}, false, function(solution, err)
      if err then
        error_handler.notify_error("Solve", err)
        return
      end
      if solution == nil or solution == "" then
        error_handler.notify_error("Solve", "No solution found.")
        return
      end
      insert_result_util.insert_result(solution, " \\rightarrow ", initial_start_pos, initial_end_pos, equation_text)
    end)
  end)
end



local function tungsten_solve_system_command(_)
  local initial_start_pos = vim.fn.getpos("'<")
  local initial_end_pos = vim.fn.getpos("'>")

  local equations_capture_ast_or_err, visual_selection_text, parse_err = cmd_utils.parse_selected_latex("system of equations")
  if parse_err then
    error_handler.notify_error("SolveSystem", parse_err)
    return
  end
  if not equations_capture_ast_or_err then return end

  if not equations_capture_ast_or_err or equations_capture_ast_or_err.type ~= "solve_system_equations_capture" then
    error_handler.notify_error("SolveSystem", "Selected text does not form a valid system of equations.")
    return
  end

  local captured_equation_asts = equations_capture_ast_or_err.equations

  vim.ui.input({ prompt = "Enter variables (e.g., x, y or x; y):" }, function(input_vars_str)
    if input_vars_str == nil or input_vars_str:match("^%s*$") then
      error_handler.notify_error("SolveSystem", "No variables entered.")
      return
    end

    local variable_names_str
    if input_vars_str:find(";") then
        variable_names_str = vim.split(input_vars_str, ";%s*")
    else
        variable_names_str = vim.split(input_vars_str, ",%s*")
    end

    local variable_asts = {}
    for _, var_name in ipairs(variable_names_str) do
        local trimmed_var_name = var_name:match("^%s*(.-)%s*$")
        if trimmed_var_name ~= "" then
            table.insert(variable_asts, { type = "variable", name = trimmed_var_name })
        end
    end

    if #variable_asts == 0 then
      error_handler.notify_error("SolveSystem", "No valid variables parsed from input.")
      return
    end

    local eq_wolfram_strs = {}
    for _, eq_ast_node in ipairs(captured_equation_asts) do
        local ok, str = pcall(wolfram_backend.to_string, eq_ast_node)
        if not ok then
          error_handler.notify_error("SolveSystem", "Failed to convert an equation to Wolfram string: " .. tostring(str))
          return
        end
        table.insert(eq_wolfram_strs, str)
    end

    local var_wolfram_strs = {}
    for _, var_ast_node in ipairs(variable_asts) do
        local ok, str = pcall(wolfram_backend.to_string, var_ast_node)
         if not ok then
            error_handler.notify_error("SolveSystem", "Failed to convert a varianle to Wolfram string: " .. tostring(str))
            return
        end
        table.insert(var_wolfram_strs, str)
    end

    solver.solve_equation_async(eq_wolfram_strs, var_wolfram_strs, true, function(result, err)
      if err then
        error_handler.notify_error("SolveSystem", err)
        return
      end
      if result == nil or result == "" then
        error_handler.notify_error("SolveSystem", "No solution found or an issue occurred.")
        return
      end
      insert_result_util.insert_result(result, " \\rightarrow ", initial_start_pos, initial_end_pos, visual_selection_text)
    end)
  end)
end

vim.api.nvim_create_user_command(
  "TungstenEvaluate",
  tungsten_eval_command,
  { range = true, desc = "Evaluate selected LaTeX and insert the result" }
)

vim.api.nvim_create_user_command(
  "TungstenDefinePersistentVariable",
  define_persistent_variable_command,
  { range = true, desc = "Define a persistent variable from the selected LaTeX assignment (e.g., x = 1+1)" }
)

vim.api.nvim_create_user_command(
  "TungstenClearCache",
  function()
    evaluator.clear_cache()
  end,
  { desc = "Clear the Tungsten evaluation cache" }
)

vim.api.nvim_create_user_command(
  "TungstenViewActiveJobs",
  function()
    evaluator.view_active_jobs()
  end,
  { desc = "View active Tungsten evaluation jobs" }
)

vim.api.nvim_create_user_command(
  "TungstenSolve",
  tungsten_solve_command,
  { range = true, desc = "Solve the selected equation for the specified variable (e.g., 'x+y=z; x')" }
)

vim.api.nvim_create_user_command(
  "TungstenSolveSystem",
  tungsten_solve_system_command,
  { range = true, desc = "Solve a system of visually selected LaTeX equations for specified variables" }
)

return {
  tungsten_eval_command = tungsten_eval_command,
  define_persistent_variable_command = define_persistent_variable_command,
  tungsten_solve_command = tungsten_solve_command,
  tungsten_solve_system_command = tungsten_solve_system_command,
}
