-- lua/tungsten/core/init.lua
local M = {}

M.registry = require 'tungsten.core.registry'
local domain_manager = require 'tungsten.core.domain_manager'

domain_manager.setup()

return M
