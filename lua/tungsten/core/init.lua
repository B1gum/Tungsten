-- lua/tungsten/core/init.lua
local M = {}

M.registry = require "tungsten.core.registry"
local cfg = require "tungsten.config"
local logger = require "tungsten.util.logger"

local domains_to_load = cfg.domains or { "arithmetic" }

logger.debug("Tungsten Debug", "Core: Initializing domains...")

local loaded_domain_modules = {}

for _, domain_name in ipairs(domains_to_load) do
  logger.debug("Tungsten Debug", "Core: Attempting to load domain module - " .. domain_name)
  local ok, domain_mod_or_err = pcall(require, "tungsten.domains." .. domain_name)
  if not ok then
    logger.error("Tungsten Core Error", ("Core Error: Failed to require domain module '%s': %s"):format(domain_name, tostring(domain_mod_or_err)))
  else
    if type(domain_mod_or_err.get_metadata) ~= "function" then
      logger.error("Tungsten Core Error", ("Core Error: Domain module '%s' does not have a get_metadata function."):format(domain_name))
    else
      local metadata = domain_mod_or_err.get_metadata()
      if not metadata or not metadata.name then
         logger.error("Tungsten Core Error", ("Core Error: Domain module '%s' get_metadata did not return valid metadata (missing name)."):format(domain_name))
      else
        M.registry.register_domain_metadata(metadata.name, metadata)
        loaded_domain_modules[metadata.name] = domain_mod_or_err
        logger.debug("Tungsten Debug", "Core: Successfully loaded and registered metadata for domain - " .. metadata.name)
      end
    end
  end
end

for _, domain_name in ipairs(domains_to_load) do
  local domain_mod = loaded_domain_modules[domain_name]
  if domain_mod and type(domain_mod.init_grammar) == "function" then
    logger.debug("Tungsten Debug", "Core: Initializing grammar for domain - " .. domain_name)
    local ok, err = pcall(domain_mod.init_grammar)
    if not ok then
      logger.error("Tungsten Core Error", ("Core Error: Failed to initialize grammar for domain '%s': %s"):format(domain_name, tostring(err)))
    else
      logger.debug("Tungsten Debug", "Core: Successfully initialized grammar for domain - " .. domain_name)
    end
  else
    logger.debug("Tungsten Debug", "Core: Domain " .. domain_name .. " has no init_grammar function. Skipping grammar initialization.")
  end
end

logger.debug("Tungsten Debug", "Core: Domain loading and grammar registration phase complete.")

return M
