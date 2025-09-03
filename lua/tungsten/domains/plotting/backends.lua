-- lua/tungsten/domains/plotting/backends.lua
-- Utilities for selecting backends and checking plotting capabilities

local backend_capabilities = require("tungsten.backends.capabilities")

local M = {}

function M.get_backend(name)
  return backend_capabilities[name]
end

function M.is_supported(backend_name, form, dim)
  local backend = M.get_backend(backend_name)
  if not backend then
    return false
  end
  local form_table = backend.supports[form]
  if not form_table then
    return false
  end
  return form_table[dim] or false
end

local function get_config()
  local ok, cfg = pcall(require, "tungsten.config")
  if ok and type(cfg) == "table" then
    return cfg
  end
  return { backend = "wolfram" }
end

function M.get_configured_backend_name()
  local cfg = get_config()
  return cfg.backend or "wolfram"
end

function M.get_configured_backend()
  return M.get_backend(M.get_configured_backend_name())
end

return M
