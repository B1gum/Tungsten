local M = {}

----------------------------------------------------------------
-- 1.  Central registry (you already wrote this file earlier)
----------------------------------------------------------------
M.registry = require("tungsten.core.registry")   -- no side‑effects

----------------------------------------------------------------
-- 2.  Legacy module aliases   (compat with pre‑refactor code)
----------------------------------------------------------------
package.loaded["tungsten.parser"]      = require("tungsten.core.parser_init")
package.loaded["tungsten.parser.core"] = require("tungsten.core.parser")

----------------------------------------------------------------
-- 3.  (Optional) load the user‑enabled domains immediately.
--     Remove if you prefer to do this elsewhere.
----------------------------------------------------------------
local cfg = require("tungsten.config")
local domains = cfg.domains or { "arithmetic" }
for _, d in ipairs(domains) do
  require("tungsten.domains." .. d)       -- each domain self‑registers
end

return M
