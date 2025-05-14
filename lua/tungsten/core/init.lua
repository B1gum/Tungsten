local M = {}

M.registry = require("tungsten.core.registry")

local cfg = require("tungsten.config")

local domains = cfg.domains or { "arithmetic" }
for _, d in ipairs(domains) do
  require("tungsten.domains." .. d)       -- each domain self‑registers
end

return M
