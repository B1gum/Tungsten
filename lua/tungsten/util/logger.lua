-- lua/tungsten/util/logger.lua
local M = {}

-- Default log level if vim.log.levels is not available
local DEFAULT_LOG_LEVEL = {
  ERROR = 1,
  WARN = 2,
  INFO = 3,
  DEBUG = 4,
}

--- Safely sends a notification or prints to console.
-- @param message string The message to log/notify.
-- @param level any The log level (e.g., vim.log.levels.ERROR or a number).
-- @param opts table (optional) Options for vim.notify, can include a 'title' field (e.g., { title = "My Title" }).
function M.notify(message, level, opts)
  opts = opts or {} -- Ensure opts is a table
  local title_str = opts.title -- Extract title string if present

  if vim and vim.notify and vim.log and vim.log.levels then
    -- Pass the opts table directly to vim.notify
    vim.notify(message, level, opts)
  else
    -- Fallback for plain Lua environments (like your test scripts)
    local level_name = "INFO" -- Default
    local vim_levels = (vim and vim.log and vim.log.levels) or DEFAULT_LOG_LEVEL

    for name, val in pairs(vim_levels) do
      if val == level then
        level_name = name
        break
      end
    end

    -- If title_str is available, prepend it.
    local prefix = title_str and ("[" .. title_str .. "] ") or ""
    print(("%s[%s] %s"):format(prefix, level_name, message))
  end
end

M.levels = (vim and vim.log and vim.log.levels) or DEFAULT_LOG_LEVEL

return M
