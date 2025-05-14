-- lua/tungsten/core/init.lua
local M = {}

M.registry = require("tungsten.core.registry")
local cfg = require("tungsten.config")
local logger = require "tungsten.util.logger" -- Added logger

if cfg.debug then
  logger.notify("Core: Initializing domains...", logger.levels.DEBUG, { title = "Tungsten Debug" })
end

local domains_to_load = cfg.domains or { "arithmetic" }
for _, domain_name in ipairs(domains_to_load) do
  if cfg.debug then
    logger.notify("Core: Loading domain - " .. domain_name, logger.levels.DEBUG, { title = "Tungsten Debug" })
  end
  local ok, domain_mod_or_err = pcall(require, "tungsten.domains." .. domain_name)
  if not ok then
    logger.notify(
      ("Core Error: Failed to load domain '%s': %s"):format(domain_name, tostring(domain_mod_or_err)),
      logger.levels.ERROR,
      { title = "Tungsten Core Error" }
    )
  elseif cfg.debug then
    logger.notify("Core: Successfully loaded domain - " .. domain_name, logger.levels.DEBUG, { title = "Tungsten Debug" })
  end
end

if cfg.debug then
  logger.notify("Core: Domain initialization finished.", logger.levels.DEBUG, { title = "Tungsten Debug" })
end

return M
