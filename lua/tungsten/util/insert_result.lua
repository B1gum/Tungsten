-- util/insert_result.lua
-- Module to insert an =-sign and the result after computation is complete
-----------------------------------------------------------------------------

local M = {}
function M.insert_result(result_text)
  local bufnr = 0
  local original_selection_text = require "tungsten.util.selection".get_visual_selection()
  if original_selection_text == "" and result_text == "" then return end

  local final_text_to_insert = original_selection_text .. " = " .. result_text

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line_api = start_pos[2] - 1
  local start_col_api = start_pos[3] - 1
  local original_end_line_api = end_pos[2] - 1
  local original_end_col_api = end_pos[3]

  local lines_to_insert = vim.fn.split(final_text_to_insert, "\n")

  vim.api.nvim_buf_set_text(
    bufnr,
    start_line_api,
    start_col_api,
    original_end_line_api,
    original_end_col_api,
    lines_to_insert
  )
end
return M

