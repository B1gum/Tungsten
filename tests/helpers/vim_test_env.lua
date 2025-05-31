-- tungsten/tests/helpers/vim_test_env.lua
-- Test helpers for running Tungsten tests in a headless Neovim instance.

local spy = require('luassert.spy')
local async = require('plenary.async')

local M = {}

local original_vim_fn_jobstart = vim.fn.jobstart
local original_config_values = {}

local jobstart_handlers = {}
local jobstart_mock_active = false

function M.mock_jobstart()
  if jobstart_mock_active then
    return
  end

  vim.fn.jobstart = spy.new(function(cmd, opts)
    local cmd_list = type(cmd) == 'string' and vim.split(cmd, ' ') or cmd
    local cmd_str = table.concat(cmd_list, " ")

    for _, entry in ipairs(jobstart_handlers) do
      if entry.matcher_fn(cmd_list, opts) then
        return entry.handler_fn(cmd_list, opts, original_vim_fn_jobstart)
      end
    end

    print("Warning: Unhandled vim.fn.jobstart call in mock: " .. cmd_str)
    if opts and opts.on_exit then
      vim.schedule(function()
        opts.on_exit(0, 1, "exit")
      end)
    end
    return 0
  end)
  jobstart_mock_active = true
end

function M.set_jobstart_handler(matcher_fn, handler_fn)
  if not jobstart_mock_active then
    M.mock_jobstart()
  end
  table.insert(jobstart_handlers, { matcher_fn = matcher_fn, handler_fn = handler_fn })
end

function M.clear_jobstart_handlers()
  jobstart_handlers = {}
end

function M.set_wolfram_response(query_substring, response_lines, exit_code, stderr_lines)
  exit_code = exit_code or 0
  response_lines = response_lines or {}
  stderr_lines = stderr_lines or {}

  local matcher = function(cmd_list, opts)
    local cmd_str = table.concat(cmd_list, " ")
    return cmd_str:match("curl") and
           cmd_str:match("api.wolframalpha.com") and
           cmd_str:match(vim.pesc(query_substring))
  end

  local handler = function(cmd_list, opts, original_fn)
    vim.schedule(function()
      if opts and opts.on_stdout and #response_lines > 0 then
        opts.on_stdout(0, {table.concat(response_lines, "\n")}, "stdout")
      end
      if opts and opts.on_stderr and #stderr_lines > 0 then
        opts.on_stderr(0, stderr_lines, "stderr")
      end
      if opts and opts.on_exit then
        opts.on_exit(0, exit_code, "exit")
      end
    end)
    return 12345
  end

  M.set_jobstart_handler(matcher, handler)
end

function M.setup_buffer(lines)
  lines = lines or { "" }
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_current_buf(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  return bufnr
end

function M.set_cursor(line, col)
  vim.api.nvim_win_set_cursor(0, { line, col - 1 })
end

function M.get_cursor()
  local pos = vim.api.nvim_win_get_cursor(0)
  return { pos[1], pos[2] + 1 }
end

function M.set_visual_selection(start_line, start_col, end_line, end_col, mode)
  mode = mode or "v"
  local bufnr = vim.api.nvim_get_current_buf()
  vim.fn.setpos("'<", { bufnr, start_line, start_col, 0 })
  vim.fn.setpos("'>", { bufnr, end_line, end_col, 0 })
end

function M.get_visual_selection_text()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  if start_pos[1] == 0 or end_pos[1] == 0 then
    return nil
  end

  local bufnr = vim.api.nvim_get_current_buf()
  if start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
    start_pos, end_pos = end_pos, start_pos
  end

  local start_line_api = start_pos[2] - 1
  local start_col_api = start_pos[3] - 1
  local end_line_api = end_pos[2] - 1
  local end_col_api = end_pos[3] -1

  if require('tungsten.util.selection') and require('tungsten.util.selection').get_visual_selection then
      return require('tungsten.util.selection').get_visual_selection()
  else
      local lines = vim.api.nvim_buf_get_text(bufnr, start_line_api, start_col_api, end_line_api, end_col_api + 1, {})
      return table.concat(lines, "\n")
  end
end

function M.get_buffer_lines(bufnr, start, end_idx)
  return vim.api.nvim_buf_get_lines(bufnr, start, end_idx, false)
end

function M.get_current_line_text()
  return vim.api.nvim_get_current_line()
end

function M.type_keys(keys, mode)
  mode = mode or "n"
  vim.api.nvim_feedkeys(keys, mode, false)
end

function M.call_command(command_string)
  vim.cmd(command_string)
end

function M.set_plugin_config(config_path, value)
  local config_module = require('tungsten.config')
  if not config_module then
    print("Error: tungsten.config module not found.")
    return
  end

  local current_table = config_module
  local original_key_path = table.concat(config_path, ".")

  local temp_table_for_original = config_module
  for i = 1, #config_path - 1 do
    if temp_table_for_original[config_path[i]] == nil then
      print("Error: Invalid config path for storing original: " .. original_key_path)
      return
    end
    temp_table_for_original = temp_table_for_original[config_path[i]]
  end
  if not original_config_values[original_key_path] then
     original_config_values[original_key_path] = temp_table_for_original[config_path[#config_path]]
  end

  for i = 1, #config_path - 1 do
    if current_table[config_path[i]] == nil then
      print("Error: Invalid config path for setting value: " .. original_key_path)
      return
    end
    current_table = current_table[config_path[i]]
  end
  current_table[config_path[#config_path]] = value
end

function M.restore_plugin_configs()
  local config_module = require('tungsten.config')
  if not config_module then
    return
  end

  for path_str, original_value in pairs(original_config_values) do
    local path_keys = vim.split(path_str, ".", { plain = true })
    local current_table = config_module
    for i = 1, #path_keys - 1 do
      if current_table[path_keys[i]] == nil then break end
      current_table = current_table[path_keys[i]]
    end
    if current_table and current_table[path_keys[#path_keys]] ~= nil then
      current_table[path_keys[#path_keys]] = original_value
    end
  end
  original_config_values = {}
end


function M.cleanup(bufnr_to_delete)
  vim.fn.jobstart = original_vim_fn_jobstart
  jobstart_mock_active = false
  M.clear_jobstart_handlers()

  M.restore_plugin_configs()

  if bufnr_to_delete then
    local buffers_to_delete = type(bufnr_to_delete) == 'table' and bufnr_to_delete or { bufnr_to_delete }
    for _, bufnr in ipairs(buffers_to_delete) do
      if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
      end
    end
  end

end

function M.inspect_table(tbl, msg)
  if msg then
    print(msg)
  end
  print(vim.inspect(tbl))
end
M.inspect = vim.inspect

return M
