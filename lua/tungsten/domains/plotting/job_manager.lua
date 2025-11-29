local queue = require("tungsten.domains.plotting.job_manager.queue")
local dependencies = require("tungsten.domains.plotting.job_manager.dependencies")

local M = {}

M.apply_output = queue.apply_output
M.submit = queue.submit
M.cancel = queue.cancel
M.cancel_all = queue.cancel_all
M.get_queue_snapshot = queue.get_queue_snapshot
M.active_jobs = queue.active_jobs
M._process_queue = queue._process_queue

function M.reset_deps_check()
	dependencies.reset()
	queue.reset_dependencies()
end

return M
