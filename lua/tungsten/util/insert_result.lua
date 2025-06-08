-- lua/tungsten/util/insert_result.lua

local M = {}

function M.insert_result(result_text, separator_text, start_pos, end_pos, original_selection_text)
  local current_separator = separator_text or " = "

  if (original_selection_text == "" or original_selection_text == nil) and (result_text == "" or result_text == nil) then
    return
  end

  local final_text_to_insert = original_selection_text .. current_separator .. (result_text or "")

  local bufnr = start_pos[1]
  local current_mode = vim.fn.mode(1)

  local start_line_api = start_pos[2] - 1
  local end_line_api = end_pos[2] - 1
  local start_col_api
  local end_col_api

  if current_mode == "V" then
    start_col_api = 0
    end_col_api = -1
  else
    start_col_api = start_pos[3] - 1
    end_col_api = end_pos[3]

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
