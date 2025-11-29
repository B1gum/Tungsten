local runner = require("tungsten.domains.plotting.workflow.runner")

local M = {}

M.run_simple = runner.run_simple
M.run_advanced = runner.run_advanced
M.run_parametric = runner.run_parametric

return M
