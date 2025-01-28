--------------------------------------------------------------------------------
-- async_lua.lua
-- Handles asynchronous interaction with the WolframEngine.
--------------------------------------------------------------------------------

local M = {}

local parser     = require("tungsten.lin_alg.parser")
local operations = require("tungsten.lin_alg.operations")
local async      = require("tungsten.async")            -- top-level async.lua
local io_utils   = require("tungsten.utils.io_utils").debug_print
local vim_api    = vim.api                              -- For convenience

--------------------------------------------------------------------------------
-- Helper: read the current visual selection as a string
--------------------------------------------------------------------------------
local function get_visual_selection()
  local start_row = vim.fn.line("'<")
  local start_col = vim.fn.col("'<")
  local end_row   = vim.fn.line("'>")
  local end_col   = vim.fn.col("'>")

  local lines = vim.fn.getline(start_row, end_row)
  lines[1]    = string.sub(lines[1], start_col)
  lines[#lines] = string.sub(lines[#lines], 1, end_col)

  local selection = table.concat(lines, "\n")
  return selection, start_row, end_row
end

--------------------------------------------------------------------------------
-- Helper: asynchronously evaluate a Wolfram expression; replace selection
--------------------------------------------------------------------------------
local function eval_and_replace_in_buffer(original_selection, wolfram_expr, numeric, start_row, end_row)
  io_utils("Evaluating => " .. wolfram_expr)

  async.run_evaluation_async(wolfram_expr, numeric, function(raw_result, err)
    if err then
      vim_api.nvim_err_writeln("Error: " .. err)
      return
    end
    if not raw_result or raw_result:find("$Failed") then
      vim_api.nvim_err_writeln("Error: Unable to evaluate equation.")
      return
    end

    -- If numeric == true, skip further parse; else parse for nicer LaTeX
    local final_result = numeric and raw_result or parser.parse_result(raw_result)
    local updated_line = original_selection .. " = " .. final_result
    updated_line = updated_line:gsub("[%z\1-\31]", "")          -- Remove control characters from output

    io_utils("Updated => " .. updated_line)

    -- Put it back into the buffer, removing extra lines
    vim.fn.setline(start_row, updated_line)
    for i = start_row+1, end_row do
      vim.fn.setline(i, "")
    end
  end)
end

--------------------------------------------------------------------------------
-- 1) Evaluate a "raw" matrix expression that might have +, -, adjacency, etc.
--------------------------------------------------------------------------------
function M.evaluate_expr_async(numeric)
  local selection, start_row, end_row = get_visual_selection()
  if not selection or selection:match("^%s*$") then
    vim_api.nvim_err_writeln("No visual selection found.")
    return
  end

  local wolfram_expr = parser.parse_linear_algebra_expr(selection)
  eval_and_replace_in_buffer(selection, wolfram_expr, numeric, start_row, end_row)
end

--------------------------------------------------------------------------------
-- 2) Evaluate det(...) of the selection
--------------------------------------------------------------------------------
function M.evaluate_det_async(numeric)
  local selection, start_row, end_row = get_visual_selection()
  local wolfram_expr = parser.parse_linear_algebra_expr(selection)

  local det_expr = operations.det(wolfram_expr)
  eval_and_replace_in_buffer(selection, det_expr, numeric, start_row, end_row)
end

--------------------------------------------------------------------------------
-- 3) Evaluate inverse(...) of the selection
--------------------------------------------------------------------------------
function M.evaluate_inv_async(numeric)
  local selection, start_row, end_row = get_visual_selection()
  local wolfram_expr = parser.parse_linear_algebra_expr(selection)

  local inv_expr = operations.inv(wolfram_expr)
  eval_and_replace_in_buffer(selection, inv_expr, numeric, start_row, end_row)
end

--------------------------------------------------------------------------------
-- 4) Evaluate transpose(...) of the selection
--------------------------------------------------------------------------------
function M.evaluate_transpose_async(numeric)
  local selection, start_row, end_row = get_visual_selection()
  local wolfram_expr = parser.parse_linear_algebra_expr(selection)

  local tr_expr = operations.transpose(wolfram_expr)
  eval_and_replace_in_buffer(selection, tr_expr, numeric, start_row, end_row)
end

--------------------------------------------------------------------------------
-- 5) Evaluate eigenvalues(...) of the selection
--------------------------------------------------------------------------------
function M.evaluate_eigenvalues_async(numeric)
  local selection, start_row, end_row = get_visual_selection()
  local wolfram_expr = parser.parse_linear_algebra_expr(selection)

  local ev_expr = operations.eigenvalues(wolfram_expr)
  eval_and_replace_in_buffer(selection, ev_expr, numeric, start_row, end_row)
end

--------------------------------------------------------------------------------
-- 6) Evaluate eigenvectors(...) of the selection
--------------------------------------------------------------------------------
function M.evaluate_eigenvectors_async(numeric)
  local selection, start_row, end_row = get_visual_selection()
  local wolfram_expr = parser.parse_linear_algebra_expr(selection)

  local vec_expr = operations.eigenvectors(wolfram_expr)
  eval_and_replace_in_buffer(selection, vec_expr, numeric, start_row, end_row)
end

--------------------------------------------------------------------------------
-- 7) Evaluate eigenbasis => basically eigen-system
--------------------------------------------------------------------------------
function M.evaluate_eigensystem_async(numeric)
  local selection, start_row, end_row = get_visual_selection()
  local wolfram_expr = parser.parse_linear_algebra_expr(selection)

  local sys_expr = operations.eigensystem(wolfram_expr)
  eval_and_replace_in_buffer(selection, sys_expr, numeric, start_row, end_row)
end

return M
