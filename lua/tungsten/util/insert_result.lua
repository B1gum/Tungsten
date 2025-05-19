-- util/insert_result.lua
-- Module to insert an =-sign and the result after computation is complete
-----------------------------------------------------------------------------

local M = {}

function M.insert_result(result_text)
  local start_row = vim.fn.line("'<")
  local start_col = vim.fn.col("'<")
  local end_row   = vim.fn.line("'>")
  local end_col   = vim.fn.col("'>")

  local lines = vim.fn.getline(start_row, end_row)
  if #lines == 0 then
    return
  end

  if #lines == 1 then
    local selection = lines[1]:sub(start_col, end_col)
    local updated = selection .. " = " .. result_text
    vim.fn.setline(start_row, updated)
  else
    lines[1] = lines[1]:sub(start_col)
    lines[#lines] = lines[#lines]:sub(1, end_col)
    local selection = table.concat(lines, "\n")
    local updated = selection .. " = " .. result_text
    local new_lines = vim.fn.split(updated, "\n")
    vim.api.nvim_buf_set_lines(0, start_row - 1, end_row, false, new_lines)
  end
end

return M
