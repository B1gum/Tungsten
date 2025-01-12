-- Manages evaluation commands.

local utils = require("tungsten.utils")
local async = require("tungsten.async")

local M = {}

-- Append equals and result asynchronously
function M.append_equals_and_result_async(numeric)
  local start_row, start_col = vim.fn.line("'<"), vim.fn.col("'<")
  local end_row, end_col     = vim.fn.line("'>"), vim.fn.col("'>")

  local lines = vim.fn.getline(start_row, end_row)
  lines[1]    = lines[1]:sub(start_col)
  lines[#lines] = lines[#lines]:sub(1, end_col)
  local selection = table.concat(lines, "\n")

  utils.debug_print("Original selection => " .. selection)
  local preprocessed = utils.preprocess_equation(selection)

  async.run_evaluation_async(preprocessed, numeric, function(raw_result, err)
    if err then
      vim.api.nvim_err_writeln("Error: " .. err)
      return
    end
    if not raw_result or raw_result:find("$Failed") then
      vim.api.nvim_err_writeln("Error: Unable to evaluate equation.")
      return
    end

    local parsed_result = numeric and raw_result or utils.parse_result(raw_result)
    local updated       = selection .. " = " .. parsed_result

    utils.debug_print("Final updated line => " .. updated)
    vim.fn.setline(start_row, updated)
    for i = start_row + 1, end_row do
      vim.fn.setline(i, "")
    end
  end)
end

-- Create user commands for exact or numeric evaluation
function M.setup_commands()
  vim.api.nvim_create_user_command("TungstenAutoEval", function()
    M.append_equals_and_result_async(false)
  end, { range = true })

  vim.api.nvim_create_user_command("TungstenAutoEvalNumeric", function()
    M.append_equals_and_result_async(true)
  end, { range = true })
end

return M

