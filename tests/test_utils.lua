--------------------------------------------------------------------------------
-- test_utils.lua
-- Utilities for Tungsten test logging: scratch buffer creation, log helpers, etc.
--------------------------------------------------------------------------------

local M = {}


-- We'll store the test buffer so we can reuse it.
local test_bufnr = nil


-- Define the log file path (relative to the current working directory)
local log_file_path = "logs/test_logs.txt"


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


-- Initialize log table
local log = {}
local test_failed = false


-- Append a log line
function M.append_log_line(msg)
  -- Write to scratch buffer
  local bufnr = M.open_test_scratch_buffer()
  vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
  vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, { msg })
  vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

  -- Accumulate logs for CI
  table.insert(log, msg)
  if msg:match("^%[FAIL%]") then
    test_failed = true
  end
end


-- A header for test logs
function M.log_header(title)
  M.append_log_line("")
  M.append_log_line("========================================")
  M.append_log_line("  " .. title)
  M.append_log_line("========================================")
end


-- Write logs to a file (only in CI)
function M.write_logs_to_file()
  if os.getenv("CI") then
    -- Ensure the logs directory exists
    os.execute("mkdir -p logs")

    local file, err = io.open(log_file_path, "w")
    if not file then
      vim.api.nvim_err_writeln("Failed to write log file: " .. err)
      return
    end

    for _, line in ipairs(log) do
      file:write(line .. "\n")
    end
    file:close()
  end
end


-- Finalize tests: write logs and exit with failure if needed
function M.finalize_tests()
  -- Write logs to file if in CI
  M.write_logs_to_file()

  if os.getenv("CI") and test_failed then
    os.exit(1)  -- Exit with failure if any test failed
  end
end


return M
