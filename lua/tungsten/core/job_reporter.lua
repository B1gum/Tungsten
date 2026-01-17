local engine = require("tungsten.core.engine")
local logger = require("tungsten.util.logger")

local M = {}

local function build_active_jobs_summary(active_jobs)
	if vim.tbl_isempty(active_jobs) then
		return "Tungsten: No active jobs."
	end

	local report = { "Active Tungsten Jobs:" }
	for id, info in pairs(active_jobs) do
		local age_ms = 0
		if info.start_time then
			age_ms = vim.loop.now() - info.start_time
		end
		local age_str = string.format("%.1fs", age_ms / 1000)
		table.insert(
			report,
			("- ID: %s, Key: %s, Buf: %s, Age: %s"):format(tostring(id), info.cache_key, tostring(info.bufnr), age_str)
		)
	end
	return table.concat(report, "\n")
end

function M.get_active_jobs_summary(active_jobs)
	active_jobs = active_jobs or engine.get_active_jobs()
	return build_active_jobs_summary(active_jobs)
end

function M.view_active_jobs(active_jobs)
	local summary = M.get_active_jobs_summary(active_jobs)
	logger.info("Tungsten", summary)
end

return M
