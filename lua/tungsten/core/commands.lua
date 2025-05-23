-- core/comands.lua
-- Defines core user-facing Neovim commands
-------------------------------------------------------------------------------

local parser    = require "tungsten.core.parser"
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


return {
  tungsten_eval_command = tungsten_eval_command,
  define_persistent_variable_command = define_persistent_variable_command
}
