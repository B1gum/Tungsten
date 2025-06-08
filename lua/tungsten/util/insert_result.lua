-- lua/tungsten/util/insert_result.lua

local M = {}

function M.insert_result(result_text, separator_text, start_pos, end_pos, original_selection_text)
  local selection_util = require("tungsten.util.selection")

  local o_text = original_selection_text
  if o_text == nil or o_text == "" then
    o_text = selection_util.get_visual_selection()
  end

  local s_pos = start_pos or vim.fn.getpos("'<")
  local e_pos = end_pos or vim.fn.getpos("'>")

  local current_separator = separator_text or " = "

  local final_text_to_insert = o_text .. current_separator .. (result_text or "")

  if not final_text_to_insert or final_text_to_insert == "" then
    return
  end

  local bufnr = s_pos[1]
  local current_mode = vim.fn.mode(1)

  local start_line_api = s_pos[2] - 1
  local end_line_api = e_pos[2] - 1
  local start_col_api
  local end_col_api

  if current_mode == "V" then
    start_col_api = 0
    end_col_api = -1
  else
    start_col_api = s_pos[3] - 1
    end_col_api = e_pos[3]

    local end_line_content = vim.api.nvim_buf_get_lines(bufnr, end_line_api, end_line_api + 1, false)[1] or ""
    if end_col_api > #end_line_content then
      end_col_api = #end_line_content
    end

    if start_line_api == end_line_api and end_col_api < start_col_api then
      end_col_api = start_col_api
    end
  end

  local lines_to_insert = vim.fn.split(final_text_to_insert, "\n")

  vim.api.nvim_buf_set_text(
    bufnr,
    start_line_api,
    start_col_api,
    end_line_api,
    end_col_api,
    lines_to_insert
  )
end

return M
