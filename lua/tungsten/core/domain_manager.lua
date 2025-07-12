local uv = vim.loop
local registry = require 'tungsten.core.registry'
local logger = require 'tungsten.util.logger'
local config = require 'tungsten.config'

local M = {}

local function default_domains_dir()
  local source = debug.getinfo(1, 'S').source:sub(2)
  local base = source:match("(.+)/core/domain_manager%.lua$")
  return base and (base .. '/domains') or 'lua/tungsten/domains'
end

function M.discover_domains(dir, user_dir)
  dir = dir or default_domains_dir()
  local domains = {}
  local seen = {}

  local function scan(path)
    if not path then return end
    local handle = uv.fs_scandir(path)
    if not handle then return end
    while true do
      local name, typ = uv.fs_scandir_next(handle)
      if not name then break end
      if typ == 'directory' and not seen[name] then
        table.insert(domains, name)
        seen[name] = true
      end
    end
  end

  scan(dir)
  scan(user_dir)

  return domains
end

function M.validate_metadata(meta)
  if type(meta) ~= 'table' then return false, 'domain module must return a table' end
  if type(meta.name) ~= 'string' then return false, 'missing name' end
  if type(meta.grammar) ~= 'table' then return false, 'missing grammar table' end
  if type(meta.grammar.contributions) ~= 'table' then return false, 'grammar.contributions must be table' end
  if meta.commands ~= nil and type(meta.commands) ~= 'table' then return false, 'commands must be table or nil' end
  if meta.handlers ~= nil and type(meta.handlers) ~= 'function' then return false, 'handlers must be function or nil' end
  return true
end

local function register_domain(meta)
  registry.register_domain_metadata(meta.name, meta)
  for _, contrib in ipairs(meta.grammar.contributions) do
    local prio = contrib.priority or meta.priority or 0
    registry.register_grammar_contribution(meta.name, prio, contrib.name, contrib.pattern, contrib.category)
  end
  if type(meta.commands) == 'table' then
    for _, cmd in ipairs(meta.commands) do
      registry.register_command(cmd)
    end
  elseif type(meta.commands) == 'function' then
    pcall(meta.commands)
  end
  if type(meta.handlers) == 'function' then pcall(meta.handlers) end
end

function M.setup(opts)
  opts = opts or {}
  local dir = opts.domains_dir or default_domains_dir()
  local domains = M.discover_domains(dir, config.user_domains_path)
  for _, name in ipairs(domains) do
    local ok, mod = pcall(require, 'tungsten.domains.' .. name)
    if not ok then
      logger.notify('DomainManager: failed to load domain ' .. name .. ': ' .. tostring(mod), logger.levels.ERROR, {title='Tungsten DomainManager'})
    else
      local valid, err = M.validate_metadata(mod)
      if not valid then
        logger.notify('DomainManager: invalid domain ' .. name .. ': ' .. tostring(err), logger.levels.ERROR, {title='Tungsten DomainManager'})
      else
        register_domain(mod)
      end
    end
  end
end

return M
