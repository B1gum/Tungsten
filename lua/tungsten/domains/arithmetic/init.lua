

local M = {}

local registry = require("tungsten.core.registry")

local base  = "tungsten.domains.arithmetic.rules."
local files = { "addsub", "fraction", "muldiv", "sqrt", "supersub" }

for _, f in ipairs(files) do
  registry.register_rule("arithmetic", require(base .. f))
end

return M
