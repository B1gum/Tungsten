-- util/selection.lua
-- Module to retrieve the visually selected text-input
-------------------------------------------------------------------------------------------

local M = {}

function M.get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos   = vim.fn.getpos("'>")

  local start_line = start_pos[2]
  local start_col  = start_pos[3]
  local end_line   = end_pos[2]
  local end_col    = end_pos[3]

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  if #lines == 0 then
    return ""
  end

  if #lines == 1 then
    return string.sub(lines[1], start_col, end_col)
  else
    lines[1] = string.sub(lines[1], start_col)
    lines[#lines] = string.sub(lines[#lines], 1, end_col)
    return table.concat(lines, "\n")
  end
end

return M

