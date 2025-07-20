-- lua/tungsten/util/insert_result.lua

local M = {}

local config = require("tungsten.config")
local state = require("tungsten.state")

function M._get_original_selection(original_selection_text)
       local selection_util = require("tungsten.util.selection")
       local text = original_selection_text
       if text == nil or text == "" then
               text = selection_util.get_visual_selection()
       end
  return text
end

function M._resolve_positions(start_pos, end_pos, selection_mode)
       local s_pos, e_pos
       local extmark_start, extmark_end

       if type(start_pos) == "number" and type(end_pos) == "number" then
               extmark_start = start_pos
               extmark_end = end_pos
               local s = vim.api.nvim_buf_get_extmark_by_id(0, state.ns, extmark_start, {})
               local e = vim.api.nvim_buf_get_extmark_by_id(0, state.ns, extmark_end, {})
               if not s or not e then
                       return nil
               end
               s_pos = { 0, s[1] + 1, s[2] + 1, 0 }
               if selection_mode == "V" then
                       e_pos = { 0, e[1], 0, 0 }
               else
                       e_pos = { 0, e[1] + 1, e[2], 0 }
               end
       else
               s_pos = start_pos or vim.fn.getpos("'<")
               e_pos = end_pos or vim.fn.getpos("'>")
       end

       return s_pos, e_pos, extmark_start, extmark_end
end

function M._compute_range(s_pos, e_pos, selection_mode)
       local bufnr = s_pos[1]
       local current_mode = selection_mode or vim.fn.mode(1)

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

       return bufnr, start_line_api, start_col_api, end_line_api, end_col_api
end

function M._notify_hooks(result_text)
       local tungsten = require("tungsten")
       tungsten._execute_hook("on_result", result_text)
       tungsten._emit_result_event(result_text)
end

function M.insert_result(result_text, separator_text, start_pos, end_pos, original_selection_text, selection_mode)
  local o_text = M._get_original_selection(original_selection_text)

  local s_pos, e_pos, extmark_start, extmark_end = M._resolve_positions(start_pos, end_pos, selection_mode)
  
  if not s_pos or not e_pos then
    return
  end

  local current_separator = separator_text or config.result_separator or " = "
  local final_text_to_insert = o_text .. current_separator .. (result_text or "")

  if not final_text_to_insert or final_text_to_insert == "" then
    return
  end

  if config.result_display == "float" then
    local float_result = require("tungsten.ui.float_result")
    float_result.show(final_text_to_insert)
    M._notify_hooks(result_text)
    return
  elseif config.result_display == "virtual" then
    local virtual_result = require("tungsten.ui.virtual_result")
    virtual_result.show(final_text_to_insert)
    M._notify_hooks(result_text)
  end

  local bufnr, start_line_api, start_col_api, end_line_api, end_col_api = M._compute_range(s_pos, e_pos, selection_mode)

  local lines_to_insert = vim.fn.split(final_text_to_insert, "\n")

  vim.api.nvim_buf_set_text(bufnr, start_line_api, start_col_api, end_line_api, end_col_api, lines_to_insert)

  if extmark_start and extmark_end then
    pcall(vim.api.nvim_buf_del_extmark, bufnr, state.ns, extmark_start)
    pcall(vim.api.nvim_buf_del_extmark, bufnr, state.ns, extmark_end)
  end

  M._notify_hooks(result_text)
end

return M
