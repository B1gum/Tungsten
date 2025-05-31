-- util/insert_result.lua
-- Module to insert an =-sign and the result after computation is complete
-----------------------------------------------------------------------------

local M = {}
function M.insert_result(result_text)
  local bufnr = vim.api.nvim_get_current_buf()
  local original_selection_text = require "tungsten.util.selection".get_visual_selection()
  if original_selection_text == "" and result_text == "" then return end

  local final_text_to_insert = original_selection_text .. " = " .. result_text

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local current_mode = vim.fn.mode(1)

  local start_line_api = start_pos[2] - 1
  local original_end_line_api = end_pos[2] - 1
  local start_col_api
  local original_end_col_api

  if current_mode == "V" then
    start_col_api = 0
    original_end_col_api = -1
  else
    start_col_api = start_pos[3] - 1

    local selection_end_line_content_table = vim.api.nvim_buf_get_lines(bufnr, original_end_line_api, original_end_line_api + 1, false)
    local selection_end_line_content = (selection_end_line_content_table and #selection_end_line_content_table > 0 and selection_end_line_content_table[1]) or ""
    local selection_end_line_len = #selection_end_line_content

    original_end_col_api = end_pos[3] - 1

    if original_end_col_api > selection_end_line_len then
      original_end_col_api = selection_end_line_len
    end

    if start_line_api == original_end_line_api and original_end_col_api < start_col_api then
      original_end_col_api = start_col_api
    end

    if start_line_api == original_end_line_api then
        local selection_start_line_content_table = vim.api.nvim_buf_get_lines(bufnr, start_line_api, start_line_api + 1, false)
        local selection_start_line_content = (selection_start_line_content_table and #selection_start_line_content_table > 0 and selection_start_line_content_table[1]) or ""
        local selection_start_line_len = #selection_start_line_content
        if start_col_api > selection_start_line_len then
            start_col_api = selection_start_line_len
            if original_end_col_api < start_col_api then
                 original_end_col_api = start_col_api
            end
        end
    end

  end

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
