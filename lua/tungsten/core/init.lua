-- lua/tungsten/core/init.lua
local M = {}

M.registry = require("tungsten.core.registry")
local domain_manager = require("tungsten.core.domain_manager")
local wolfram_backend = require("tungsten.backends.wolfram")

domain_manager.setup()
wolfram_backend.reload_handlers()

return M
