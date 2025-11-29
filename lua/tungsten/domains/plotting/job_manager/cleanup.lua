local M = {}

local function unlink(pathname)
	if pathname and pathname ~= "" then
		pcall(vim.loop.fs_unlink, pathname)
	end
end

function M.cleanup_temp(job, include_outputs)
	if not job or not job.plot_opts then
		return
	end

	if job.plot_opts.temp_file then
		unlink(job.plot_opts.temp_file)
	end

	if include_outputs then
		local out_path = job.plot_opts.out_path
		if out_path and out_path ~= "" then
			unlink(out_path)

			local format = job.plot_opts.format
			if format and format ~= "" then
				local has_extension = out_path:match("%.[^/%.]+$") ~= nil
				if not has_extension then
					unlink(string.format("%s.%s", out_path, format))
				end
			end
		end
	end
end

function M.notify_job_cancelled(job)
	if not job then
		return
	end

	local err = {
		code = -1,
		exit_code = -1,
		cancelled = true,
	}

	if job.on_error then
		job.on_error(err)
	else
		M.cleanup_temp(job, true)
	end
end

return M
