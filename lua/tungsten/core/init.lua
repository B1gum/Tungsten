-- lua/tungsten/core/init.lua
local M = {}

M.registry = require("tungsten.core.registry")
local domain_manager = require("tungsten.core.domain_manager")
local backend_manager = require("tungsten.backends.manager")
local config = require("tungsten.config")

domain_manager.setup()

local backend = type(backend_manager.current) == "function" and backend_manager.current()

if backend then
	backend.load_handlers(config.domains, M.registry)
end

return M
