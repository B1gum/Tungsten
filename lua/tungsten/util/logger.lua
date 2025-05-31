-- tungsten/lua/tungsten/util/logger.lua
local M = {}

local DEFAULT_LOG_LEVELS = {
  ERROR = 1,
  WARN = 2,
  INFO = 3,
  DEBUG = 4,
}

function M.notify(message, level, opts)
  opts = opts or {}

  if vim and vim.notify and vim.log and vim.log.levels then
    vim.schedule(function()
      vim.notify(message, level, opts)
    end)
  else
    local level_name = "INFO"
    local current_levels = (vim and vim.log and vim.log.levels) or DEFAULT_LOG_LEVELS

    for name, val in pairs(current_levels) do
      if val == level then
        level_name = name
        break
      end
    end

    local prefix = opts.title and ("[" .. opts.title .. "] ") or ""
    print(("%s[%s] %s"):format(prefix, level_name, message))
  end
end

M.levels = (vim and vim.log and vim.log.levels) or DEFAULT_LOG_LEVELS

return M

