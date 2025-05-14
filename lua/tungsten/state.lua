-- state.lua
-- Keeps track of runtime state
----------------------------------------------
local M = {}

M.ns          = vim.api.nvim_create_namespace 'tungsten'
M.active_jobs = {}      -- job_id → {bufnr, expr_key, timer, etc.}
M.cache       = {}      -- expr_key → result
M.config      = {}      -- copy of user config from setup()

return M
