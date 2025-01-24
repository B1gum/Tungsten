--------------------------------------------------------------------------------
-- test_utils.lua
-- Utilities for Tungsten test logging: scratch buffer creation, log helpers, etc.
--------------------------------------------------------------------------------

local M = {}

-- We'll store the test buffer so we can reuse it.
local test_bufnr = nil

-- Open (or reuse) a scratch buffer for logging
function M.open_test_scratch_buffer()
  if test_bufnr and vim.api.nvim_buf_is_valid(test_bufnr) then
    return test_bufnr
  end

  test_bufnr = vim.api.nvim_create_buf(false, true)  -- No file on disk, scratch buffer
  vim.api.nvim_buf_set_option(test_bufnr, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(test_bufnr, "filetype", "tungstentest")

  vim.api.nvim_command("botright vsplit")
  vim.api.nvim_set_current_buf(test_bufnr)
  return test_bufnr
end

-- Append a log line
function M.append_log_line(msg)
  local bufnr = M.open_test_scratch_buffer()
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { msg })
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
end

-- A header for test logs
function M.log_header(title)
  M.append_log_line("")
  M.append_log_line("========================================")
  M.append_log_line("  " .. title)
  M.append_log_line("========================================")
end

return M
