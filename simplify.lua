----------------------------------------------------------------------------------
-- simplify.lua
-- Manages simplification commands
---------------------------------------------------------------------------------

-- 1) Setup
---------------------------------------------------------------------------------
local io_utils = require("tungsten.utils.io_utils").debug_print
local parser = require("tungsten.utils.parser")
local async = require("tungsten.async")

local M = {}




-- 2) Append equals and simplify asynchronously
---------------------------------------------------------------------------------
function M.append_equals_and_simplify_async(numeric)
  local start_row, start_col = vim.fn.line("'<"), vim.fn.col("'<")  -- Extracts start of visual selection
  local end_row, end_col     = vim.fn.line("'>"), vim.fn.col("'>")  -- Extracts end of visual selection
  local lines                = vim.fn.getline(start_row, end_row)   -- lines is the rows from the start of the selection till the end

  lines[1]    = lines[1]:sub(start_col)                             -- Trim whitespace before selection
  lines[#lines] = lines[#lines]:sub(1, end_col)                     -- Trim whitespace after selection
  local selection = table.concat(lines, "\n")                       -- Concatenate the selection into a single string with rows seperated by \n

  io_utils("Original selection for simplify => " .. selection)             -- (Optionally) print the original selection for the simplification
  local preprocessed = parser.preprocess_equation(selection)                         -- Preprocess the equation with preprocess_equation

  async.run_simplify_async(preprocessed, numeric, function(raw_result, err)         -- Run the simplify-command asynchronously
    if err then                                                                     -- If an error occurs, then
      vim.api.nvim_err_writeln("Error: " .. err)                                    -- print the error to the error-log
      return
    end
    if not raw_result or raw_result:find("$Failed") then                            -- If no result is found, then
      vim.api.nvim_err_writeln("Error: Unable to simplify equation.")               -- print an error to the error-log
      return
    end

    local parsed_result = numeric and raw_result or parser.parse_result(raw_result)  -- Parse the result with parse_result if the symbolic version of the command is chosen
    local updated       = selection .. " = " .. parsed_result                       -- Save the line to be pasted to the buffer

    io_utils("Final updated line => " .. updated)                          -- (Optionally) print the final processed line
    vim.fn.setline(start_row, updated)                                              -- Print the updated line to the buffer
    for i = start_row + 1, end_row do                                               -- For all following rows in the selection
      vim.fn.setline(i, "")                                                         -- replace rows with empty strings
    end
  end)
end




-- 3) Create user commands for simplify
---------------------------------------------------------------------------------
function M.setup_commands()
  vim.api.nvim_create_user_command("TungstenAutoSimplify", function()
    M.append_equals_and_simplify_async(false)
  end, { range = true })

  vim.api.nvim_create_user_command("TungstenAutoSimplifyNumeric", function()
    M.append_equals_and_simplify_async(true)
  end, { range = true })
end

return M
