-- tungsten/lua/tungsten/util/logger.lua
local M = {}

local neovim_levels = vim and vim.log and vim.log.levels
M.levels = neovim_levels or { DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 }

local DEFAULT_LOG_LEVELS = M.levels

local current_level = M.levels.INFO

function M.set_level(level)
  if type(level) == "string" then
    level = M.levels[level:upper()] or current_level
  end
  if type(level) == "number" then
    current_level = level
  end
end

function M.get_level()
  return current_level
end

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

local function send(level, title, msg)
  if level < current_level then return end
  if msg == nil then
    msg = title
    title = "Tungsten"
  end
  M.notify(msg, level, { title = title })
end

function M.debug(title, msg) send(M.levels.DEBUG, title, msg) end
function M.info(title, msg) send(M.levels.INFO, title, msg) end
function M.warn(title, msg) send(M.levels.WARN, title, msg) end
function M.error(title, msg) send(M.levels.ERROR, title, msg) end

return M

