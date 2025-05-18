-- lua/tungsten/core/init.lua
local M = {}

M.registry = require("tungsten.core.registry")
local cfg = require("tungsten.config")
local logger = require "tungsten.util.logger"

local domains_to_load = cfg.domains or { "arithmetic" }

if cfg.debug then
  logger.notify("Core: Initializing domains...", logger.levels.DEBUG, { title = "Tungsten Debug" })
end

local loaded_domain_modules = {}

for _, domain_name in ipairs(domains_to_load) do
  if cfg.debug then
    logger.notify("Core: Attempting to load domain module - " .. domain_name, logger.levels.DEBUG, { title = "Tungsten Debug" })
  end
  local ok, domain_mod_or_err = pcall(require, "tungsten.domains." .. domain_name)
  if not ok then
    logger.notify(
      ("Core Error: Failed to require domain module '%s': %s"):format(domain_name, tostring(domain_mod_or_err)),
      logger.levels.ERROR, { title = "Tungsten Core Error" }
    )
  else
    if type(domain_mod_or_err.get_metadata) ~= "function" then
      logger.notify(
        ("Core Error: Domain module '%s' does not have a get_metadata function."):format(domain_name),
        logger.levels.ERROR, { title = "Tungsten Core Error" }
      )
    else
      local metadata = domain_mod_or_err.get_metadata()
      if not metadata or not metadata.name then
         logger.notify(
            ("Core Error: Domain module '%s' get_metadata did not return valid metadata (missing name)."):format(domain_name),
            logger.levels.ERROR, { title = "Tungsten Core Error" }
        )
      else
        M.registry.register_domain_metadata(metadata.name, metadata)
        loaded_domain_modules[metadata.name] = domain_mod_or_err
        if cfg.debug then
            logger.notify("Core: Successfully loaded and registered metadata for domain - " .. metadata.name, logger.levels.DEBUG, { title = "Tungsten Debug" })
        end
      end
    end
  end
end

for domain_name, domain_mod in pairs(loaded_domain_modules) do
  if type(domain_mod.init_grammar) == "function" then
    if cfg.debug then
      logger.notify("Core: Initializing grammar for domain - " .. domain_name, logger.levels.DEBUG, { title = "Tungsten Debug" })
    end
    local ok, err = pcall(domain_mod.init_grammar)
    if not ok then
      logger.notify(
        ("Core Error: Failed to initialize grammar for domain '%s': %s"):format(domain_name, tostring(err)),
        logger.levels.ERROR, { title = "Tungsten Core Error" }
      )
    elseif cfg.debug then
       logger.notify("Core: Successfully initialized grammar for domain - " .. domain_name, logger.levels.DEBUG, { title = "Tungsten Debug" })
    end
  else
     if cfg.debug then
      logger.notify("Core: Domain " .. domain_name .. " has no init_grammar function. Skipping grammar initialization.", logger.levels.DEBUG, { title = "Tungsten Debug" })
    end
  end
end


if cfg.debug then
  logger.notify("Core: Domain loading and grammar registration phase complete.", logger.levels.DEBUG, { title = "Tungsten Debug" })
end

return M
