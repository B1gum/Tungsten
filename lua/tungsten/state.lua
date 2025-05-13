local M = {}

M.ns          = vim.api.nvim_create_namespace 'tungsten'
M.active_jobs = {}      -- job_id → {bufnr, expr, timer}
M.cache       = {}      -- optional result cache
M.config      = {}      -- copy of user config from setup()

return M
