-- lua/tungsten/util/logger.lua
local M = {}

local DEFAULT_LOG_LEVELS = {
  ERROR = 1,
  WARN = 2,
  INFO = 3,
  DEBUG = 4,
}

function M.notify(message, level, opts)
  opts = opts or {}
  local title_str = opts.title

  if vim and vim.notify and vim.log and vim.log.levels then
    vim.notify(message, level, opts)
  else
    local level_name = "INFO"
    local vim_levels = (vim and vim.log and vim.log.levels) or DEFAULT_LOG_LEVELS

    for name, val in pairs(vim_levels) do
      if val == level then
        level_name = name
        break
      end
    end

    local prefix = title_str and ("[" .. title_str .. "] ") or ""
    print(("%s[%s] %s"):format(prefix, level_name, message))
  end
end

M.levels = (vim and vim.log and vim.log.levels) or DEFAULT_LOG_LEVELS

return M
