-- insert_result.lua
-- Module to insert an =-sign and the result after computation is complete
-----------------------------------------------------------------------------

local M = {}

--- Inserts the given result text after the visual selection.
-- @param result_text (string) The text to insert (e.g., " = 4").
function M.insert_result(result_text)
  -- Get the visual selection boundaries.
  local start_row = vim.fn.line("'<")
  local start_col = vim.fn.col("'<")
  local end_row   = vim.fn.line("'>")
  local end_col   = vim.fn.col("'>")
  
  -- Get the lines that are part of the visual selection.
  local lines = vim.fn.getline(start_row, end_row)
  if #lines == 0 then
    return
  end
  
  if #lines == 1 then
    -- Single-line selection: extract only the selected text.
    local selection = lines[1]:sub(start_col, end_col)
    local updated = selection .. " = " .. result_text
    -- Replace the entire line with the updated text.
    vim.fn.setline(start_row, updated)
  else
    -- Multi-line selection:
    -- Trim the first line (from the start column) and the last line (up to the end column).
    lines[1] = lines[1]:sub(start_col)
    lines[#lines] = lines[#lines]:sub(1, end_col)
    local selection = table.concat(lines, "\n")
    local updated = selection .. " = " .. result_text
    -- Split the updated text back into lines.
    local new_lines = vim.split(updated, "\n")
    vim.api.nvim_buf_set_lines(0, start_row - 1, end_row, false, new_lines)
  end
end

return M
