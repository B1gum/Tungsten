-- selection.lua
-- Module to retrieve the visually selected text-input
-------------------------------------------------------------------------------------------

local M = {}

--- Retrieves the text currently selected in visual mode.
-- @return (string) The selected text.
function M.get_visual_selection()
  -- Get the starting and ending positions of the visual selection.
  local start_pos = vim.fn.getpos("'<")  -- returns {bufnum, start_line, start_col, off}
  local end_pos   = vim.fn.getpos("'>")   -- returns {bufnum, end_line, end_col, off}

  local start_line = start_pos[2]
  local start_col  = start_pos[3]
  local end_line   = end_pos[2]
  local end_col    = end_pos[3]

  -- Fetch all lines that are part of the selection.
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  if #lines == 0 then
    return ""
  end

  if #lines == 1 then
    -- Single-line selection: extract substring from start_col to end_col.
    return string.sub(lines[1], start_col, end_col)
  else
    -- Multi-line selection: trim the first and last lines to selection boundaries.
    lines[1] = string.sub(lines[1], start_col)
    lines[#lines] = string.sub(lines[#lines], 1, end_col)
    return table.concat(lines, "\n")
  end
end

return M

