local logger = require("tungsten.util.logger")
local state = require("tungsten.state")

local JobCoordinator = {}

function JobCoordinator.is_job_already_running(cache_key)
	for job_id_running, job_info in pairs(state.active_jobs) do
		if job_info.cache_key == cache_key then
			local notify_msg = "Tungsten: Evaluation already in progress for this expression."
			logger.info("Tungsten", notify_msg)
			logger.debug(
				"Tungsten Debug",
				("Tungsten: Evaluation already in progress for key: '%s' (Job ID: %s)"):format(
					cache_key,
					tostring(job_id_running)
				)
			)
			logger.notify(notify_msg, logger.levels.INFO, { title = "Tungsten" })
			return true
		end
	end

	return false
end

return JobCoordinator
