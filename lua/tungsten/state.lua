-- state.lua
-- Keeps track of runtime state
----------------------------------------------
local M = {}

M.ns          = vim.api.nvim_create_namespace 'tungsten'
M.active_jobs = {}
M.cache       = {}
M.config      = {}

return M
