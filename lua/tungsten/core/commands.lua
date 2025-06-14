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
local state     = require "tungsten.state"
local wolfram_backend = require "tungsten.backends.wolfram"
local vim_inspect = require "vim.inspect"

local function tungsten_eval_command(_)
  local text = selection.get_visual_selection()
  if text == "" or text == nil then
    logger.notify("Tungsten: No text selected.", logger.levels.ERROR)
    return
  end

  local ok, ast_or_err = pcall(parser.parse, text)
  if not ok or not ast_or_err then
    logger.notify("Tungsten: parse error – " .. tostring(ast_or_err), logger.levels.ERROR)
    return
  end
  local ast = ast_or_err

  local use_numeric_mode = config.numeric_mode

  evaluator.evaluate_async(ast, use_numeric_mode, function(result)
    if result == nil or result == "" then
      return
    end
    insert_result_util.insert_result(result)
  end)
end


local function trim_whitespace(str)
  if type(str) ~= "string" then
    return str
  end
  return str:match("^%s*(.-)%s*$")
end

local function define_persistent_variable_command(_)
  local selected_text = selection.get_visual_selection()
  if selected_text == "" or selected_text == nil then
    logger.notify("Tungsten: No text selected for variable definition.", logger.levels.ERROR, { title = "Tungsten Error" })
    return
  end

  local configured_op_str = config.persistent_variable_assignment_operator
  if configured_op_str ~= "=" and configured_op_str ~= ":=" then
    logger.notify("Tungsten: Invalid assignment operator in config. Using ':='.", logger.levels.WARN, { title = "Tungsten Warning" })
    configured_op_str = ":="
  end

  local op_to_use_str = nil
  local op_start_pos = nil

  local op_double_start, op_double_end = selected_text:find(":=", 1, true)
  local op_single_start, op_single_end = selected_text:find("=", 1, true)

  if op_double_start then
    op_to_use_str = ":="
    op_start_pos = op_double_start
    if config.debug then
      logger.notify("Tungsten Debug: Operator ':=' found at pos " .. tostring(op_start_pos), logger.levels.DEBUG, { title = "Tungsten Debug" })
    end
  elseif op_single_start then
    op_to_use_str = "="
    op_start_pos = op_single_start
    if config.debug then
      logger.notify("Tungsten Debug: Operator '=' found at pos " .. tostring(op_start_pos), logger.levels.DEBUG, { title = "Tungsten Debug" })
    end
  end

  if not op_start_pos then
    logger.notify("Tungsten: No assignment operator ('=' or ':=') found in selection.", logger.levels.ERROR, { title = "Tungsten Error" })
    return
  end

  local var_name_end_index = op_start_pos - 1
  if var_name_end_index < 0 then var_name_end_index = 0 end

  local raw_part1 = selected_text:sub(1, var_name_end_index)
  if config.debug then
      logger.notify("Tungsten Debug: Raw parts[1] before trim: '" .. raw_part1 .. "' (op_start_pos was " .. tostring(op_start_pos) .. ")", logger.levels.DEBUG, {title = "Tungsten Debug"})
  end
  local var_name_str = trim_whitespace(raw_part1)

  local rhs_start_index = op_start_pos + #op_to_use_str
  local raw_part2 = selected_text:sub(rhs_start_index)
  if config.debug then
      logger.notify("Tungsten Debug: Raw parts[2] before trim: '" .. raw_part2 .. "' (rhs_start_index was " .. tostring(rhs_start_index) .. ", operator was '" .. op_to_use_str .. "')", logger.levels.DEBUG, {title = "Tungsten Debug"})
  end
  local rhs_latex_str = trim_whitespace(raw_part2)

  if var_name_str == "" then
    logger.notify("Tungsten: Variable name cannot be empty.", logger.levels.ERROR, { title = "Tungsten Error" })
    return
  end

  if rhs_latex_str == "" then
    logger.notify("Tungsten: Variable definition (LaTeX) cannot be empty.", logger.levels.ERROR, { title = "Tungsten Error" })
    return
  end

  if config.debug then
    logger.notify("Tungsten Debug: Defining variable '" .. var_name_str .. "' with LaTeX RHS: '" .. rhs_latex_str .. "'", logger.levels.DEBUG, { title = "Tungsten Debug" })
  end

  local parse_ok, definition_ast_or_err = pcall(parser.parse, rhs_latex_str)
  if not parse_ok or not definition_ast_or_err then
    logger.notify("Tungsten: Failed to parse LaTeX definition for '" .. var_name_str .. "': " .. tostring(definition_ast_or_err), logger.levels.ERROR, { title = "Tungsten Error" })
    return
  end
  local definition_ast = definition_ast_or_err

  if config.debug then
    logger.notify("Tungsten Debug: AST for '" ..var_name_str.. "' before to_string: " .. vim_inspect(definition_ast), logger.levels.DEBUG, { title = "Tungsten Debug" })
  end

  local conversion_ok, wolfram_definition_str_or_err = pcall(wolfram_backend.to_string, definition_ast)

  if config.debug then
    logger.notify("Tungsten Debug: pcall result for to_string: conversion_ok=" .. tostring(conversion_ok) .. ", returned_value=" .. vim_inspect(wolfram_definition_str_or_err), logger.levels.DEBUG, { title = "Tungsten Debug" })
  end

  if not conversion_ok or not wolfram_definition_str_or_err or type(wolfram_definition_str_or_err) ~= "string" then
    logger.notify("Tungsten: Failed to convert definition AST to Wolfram string for '" .. var_name_str .. "': " .. tostring(wolfram_definition_str_or_err), logger.levels.ERROR, { title = "Tungsten Error" })
    return
  end
  local wolfram_definition_str = wolfram_definition_str_or_err

  if config.debug then
    logger.notify("Tungsten Debug: Storing variable '" .. var_name_str .. "' with Wolfram string: '" .. wolfram_definition_str .. "'", logger.levels.DEBUG, { title = "Tungsten Debug" })
  end

  state.persistent_variables = state.persistent_variables or {}
  state.persistent_variables[var_name_str] = wolfram_definition_str

  logger.notify("Tungsten: Defined persistent variable '" .. var_name_str .. "' as '" .. wolfram_definition_str .. "'.", logger.levels.INFO, { title = "Tungsten" })
end


local function tungsten_solve_command(_)
  local initial_start_pos = vim.fn.getpos("'<")
  local initial_end_pos = vim.fn.getpos("'>")

  if initial_start_pos[2] == 0 and initial_start_pos[3] == 0 and initial_end_pos[2] == 0 and initial_end_pos[3] == 0 then
    logger.notify("TungstenSolve: No equation selected (visual selection marks invalid).", logger.levels.ERROR, { title = "Tungsten Error"})
    return
  end

  local equation_text = selection.get_visual_selection()

  if equation_text == "" or equation_text == nil then
     logger.notify("TungstenSolve: Selected equation text is empty. Will attempt to insert result at selection point.", logger.levels.WARN, { title = "Tungsten Warning"})
  end

  local eq_parse_ok, parsed_ast_top = pcall(parser.parse, equation_text)
  if not eq_parse_ok or not parsed_ast_top then
    logger.notify("TungstenSolve: Parse error for equation: " .. tostring(parsed_ast_top or "nil"), logger.levels.ERROR, { title = "Tungsten Error" })
    return
  end

  local eq_ast
  if parsed_ast_top.type == "solve_system_equations_capture" then
    if parsed_ast_top.equations and #parsed_ast_top.equations == 1 then
      eq_ast = parsed_ast_top.equations[1]
      if config.debug then
        logger.notify("TungstenSolve: Extracted single equation from system capture.", logger.levels.DEBUG, {title="Tungsten Debug"})
      end
    else
      logger.notify("TungstenSolve: Parsed as system with not exactly one equation. AST: " .. vim.inspect(parsed_ast_top), logger.levels.ERROR, { title = "Tungsten Error" })
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
    logger.notify("TungstenSolve: Selected text is not a valid single equation. Effective AST: " .. vim.inspect(eq_ast), logger.levels.ERROR, { title = "Tungsten Error" })
    return
  end

  vim.ui.input({ prompt = "Enter variable to solve for (e.g., x):" }, function(var_input_str)
    if var_input_str == nil or var_input_str == "" then
      logger.notify("TungstenSolve: No variable entered.", logger.levels.WARN, { title = "Tungsten Warning" })
      return
    end
    local trimmed_var_name = var_input_str:match("^%s*(.-)%s*$")
    if trimmed_var_name == "" then
      logger.notify("TungstenSolve: Variable cannot be empty.", logger.levels.ERROR, { title = "Tungsten Error" })
      return
    end

    local var_parse_ok, var_ast = pcall(parser.parse, trimmed_var_name)
    if not var_parse_ok or not var_ast or var_ast.type ~= "variable" then
      logger.notify("TungstenSolve: Invalid variable: '" .. trimmed_var_name .. "'. Parsed as: " .. vim.inspect(var_ast), logger.levels.ERROR, { title = "Tungsten Error" })
      return
    end

    local eq_wolfram_ok, eq_wolfram_str = pcall(wolfram_backend.to_string, eq_ast)
    if not eq_wolfram_ok or not eq_wolfram_str then
      logger.notify("TungstenSolve: Failed to convert equation: " .. tostring(eq_wolfram_str), logger.levels.ERROR, {title = "Tungsten Error"})
      return
    end
    local var_wolfram_ok, var_wolfram_str = pcall(wolfram_backend.to_string, var_ast)
    if not var_wolfram_ok or not var_wolfram_str then
      logger.notify("TungstenSolve: Failed to convert variable: " .. tostring(var_wolfram_str), logger.levels.ERROR, {title = "Tungsten Error"})
      return
    end

    solver.solve_equation_async({eq_wolfram_str}, {var_wolfram_str}, false, function(solution, err)
      if err then
        logger.notify("TungstenSolve: Solver error: " .. tostring(err), logger.levels.ERROR, { title = "Tungsten Error"})
        return
      end
      if solution == nil or solution == "" then
        logger.notify("TungstenSolve: No solution found.", logger.levels.WARN, { title = "Tungsten Warning"})
        return
      end
      insert_result_util.insert_result(solution, " \\rightarrow ", initial_start_pos, initial_end_pos, equation_text)
    end)
  end)
end



local function tungsten_solve_system_command(_)
  local initial_start_pos = vim.fn.getpos("'<")
  local initial_end_pos = vim.fn.getpos("'>")
  local visual_selection_text = selection.get_visual_selection()
  if visual_selection_text == "" or visual_selection_text == nil then
    logger.notify("TungstenSolveSystem: No equations selected.", logger.levels.ERROR, { title = "Tungsten Error" })
    return
  end

  local equations_capture_ast_or_err
  local parse_eq_ok, parsed_eq_result = pcall(parser.parse, visual_selection_text)

  if not parse_eq_ok or not parsed_eq_result then
    logger.notify("TungstenSolveSystem: Parse error for equations: " .. tostring(parsed_eq_result or "nil"), logger.levels.ERROR, { title = "Tungsten Error" })
    return
  end
  equations_capture_ast_or_err = parsed_eq_result

  if not equations_capture_ast_or_err or equations_capture_ast_or_err.type ~= "solve_system_equations_capture" then
    logger.notify("TungstenSolveSystem: Selected text does not form a valid system of equations. Parsed as: " .. (equations_capture_ast_or_err and equations_capture_ast_or_err.type or "nil"), logger.levels.ERROR, { title = "Tungsten Error" })
    return
  end

  local captured_equation_asts = equations_capture_ast_or_err.equations

  vim.ui.input({ prompt = "Enter variables (e.g., x, y or x; y):" }, function(input_vars_str)
    if input_vars_str == nil or input_vars_str:match("^%s*$") then
      logger.notify("TungstenSolveSystem: No variables entered.", logger.levels.WARN, { title = "Tungsten Warning" })
      return
    end

    local variable_names_str = {}
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
      logger.notify("TungstenSolveSystem: No valid variables parsed from input.", logger.levels.ERROR, { title = "Tungsten Error" })
      return
    end

    local eq_wolfram_strs = {}
    for _, eq_ast_node in ipairs(captured_equation_asts) do
        local ok, str = pcall(wolfram_backend.to_string, eq_ast_node)
        if not ok then
            logger.notify("TungstenSolveSystem: Failed to convert an equation to Wolfram string: " .. tostring(str), logger.levels.ERROR, {title = "Tungsten Error"})
            return
        end
        table.insert(eq_wolfram_strs, str)
    end

    local var_wolfram_strs = {}
    for _, var_ast_node in ipairs(variable_asts) do
        local ok, str = pcall(wolfram_backend.to_string, var_ast_node)
         if not ok then
            logger.notify("TungstenSolveSystem: Failed to convert a variable to Wolfram string: " .. tostring(str), logger.levels.ERROR, {title = "Tungsten Error"})
            return
        end
        table.insert(var_wolfram_strs, str)
    end

    solver.solve_equation_async(eq_wolfram_strs, var_wolfram_strs, true, function(result, err)
      if err then
        logger.notify("TungstenSolveSystem: Error during system evaluation: " .. tostring(err), logger.levels.ERROR, { title = "Tungsten Error" })
        return
      end
      if result == nil or result == "" then
        logger.notify("TungstenSolveSystem: No solution found or an issue occurred.", logger.levels.WARN, { title = "Tungsten Warning" })
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
