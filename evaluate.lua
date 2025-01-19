--------------------------------------------------------------------------------
-- evaluate.lua
-- Manages symbolic and numerical evaluation commands
--------------------------------------------------------------------------------

-- 1) Setup
--------------------------------------------------------------------------------
local io_utils = require("tungsten.utils.io_utils").debug_print
local parser = require("tungsten.utils.parser")
local async = require("tungsten.async")

local M = {}


-- 2) Define function to call the Wolfram engine on the selected function and append the result in the buffer
--------------------------------------------------------------------------------
-- Append equals and result asynchronously
function M.append_equals_and_result_async(numeric)
  local start_row, start_col = vim.fn.line("'<"), vim.fn.col("'<") -- Picks up starting point of visual selection
  local end_row, end_col     = vim.fn.line("'>"), vim.fn.col("'>") -- Picks up end-point of visual selection

  local lines = vim.fn.getline(start_row, end_row) -- lines is all rows between start_row and end_row
  lines[1]    = lines[1]:sub(start_col) -- Trim the first line to remove whitespace before selection
  lines[#lines] = lines[#lines]:sub(1, end_col) -- Trim the last line to remove whitespace after selection
  local selection = table.concat(lines, "\n") -- Joins adjusted lines together into a single string seperated by newline characters

  io_utils("Original selection => " .. selection) -- (Optionally) prints the original selection 
  local preprocessed = parser.preprocess_equation(selection) -- Preprocess the selected equation with parser.preprocess_equation

  async.run_evaluation_async(preprocessed, numeric, function(raw_result, err) -- Call the async.run_evaluation_async to actually run the command in the wolfram engine
    if err then -- If an error occured during evaluation then
      vim.api.nvim_err_writeln("Error: " .. err) -- Write the error message to the error-log
      return -- Exit the callback
    end
    if not raw_result or raw_result:find("$Failed") then -- If no result is outputted or the outputted result is the $Failed-flag then
      vim.api.nvim_err_writeln("Error: Unable to evaluate equation.") -- Print error message to the error-log
      return -- Exit the callback
    end

    local parsed_result = numeric and raw_result or parser.parse_result(raw_result) -- If numeric is true pass raw_result, else pass raw_result to parse_result
    local updated       = selection .. " = " .. parsed_result -- Concatenates the original selection with an = and the parsed_result

    io_utils("Final updated line => " .. updated) -- (Optionally) print the final updated line
    vim.fn.setline(start_row, updated) -- Replaces the original selection with the updated line that includes the parsed result
    for i = start_row + 1, end_row do -- Loops through all subsequent lines in the selection
      vim.fn.setline(i, "") -- Set lines to an empty string
    end
  end)
end

-- 3) Create user commands for exact or numeric evaluation
--------------------------------------------------------------------------------
function M.setup_commands()
  vim.api.nvim_create_user_command("TungstenAutoEval", function() -- Create symbolic evaluation function
    M.append_equals_and_result_async(false) -- Set numeric-flag to False
  end, { range = true })

  vim.api.nvim_create_user_command("TungstenAutoEvalNumeric", function() -- Create numeric evaluation function
    M.append_equals_and_result_async(true) -- Set numeric-flag to True
  end, { range = true })
end

return M

