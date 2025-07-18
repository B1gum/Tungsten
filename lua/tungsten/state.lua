-- state.lua
-- Keeps track of runtime state
----------------------------------------------
local config = require("tungsten.config")
local Cache = require("tungsten.cache")

local M = {}

M.ns = vim.api.nvim_create_namespace("tungsten")
M.active_jobs = {}
M.cache = Cache.new(config.cache_max_entries, config.cache_ttl)
M.config = config
M.persistent_variables = {}

return M
