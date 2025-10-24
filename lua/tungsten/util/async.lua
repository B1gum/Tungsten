-- lua/tungsten/util/async.lua
-- Utilities for spawning external processes asynchronously.

local state = require("tungsten.state")
local logger = require("tungsten.util.logger")
local config = require("tungsten.config")

local M = {}

local job_queue = {}
local process_queue

local function active_job_count()
	local n = 0
	for _ in pairs(state.active_jobs) do
		n = n + 1
	end
	return n
end

local function spawn_process(cmd, opts)
	opts = opts or {}
	local cache_key = opts.cache_key
	local on_exit = opts.on_exit or opts.on_complete
	local timeout = opts.timeout or config.process_timeout_ms or 10000

	local stdout_chunks, stderr_chunks = {}, {}

	local completed = false
	local handle

	local function finalize(code)
		if completed then
			return
		end
		completed = true

		if handle and handle.id and state.active_jobs[handle.id] then
			state.active_jobs[handle.id] = nil
		end

		process_queue()

		if on_exit then
			local stdout = table.concat(stdout_chunks, "\n"):gsub("^%s*(.-)%s*$", "%1")
			local stderr = table.concat(stderr_chunks, "\n"):gsub("^%s*(.-)%s*$", "%1")
			vim.schedule(function()
				on_exit(code, stdout, stderr)
			end)
		end
	end

	local Job = require("plenary.job")
	local job = Job:new({
		command = cmd[1],
		args = vim.list_slice(cmd, 2),
		enable_recording = true,
		on_stdout = function(_, line)
			if line then
				table.insert(stdout_chunks, line)
			end
		end,
		on_stderr = function(_, line)
			if line then
				table.insert(stderr_chunks, line)
			end
		end,
		on_exit = function(j, code)
			stdout_chunks = j:result()
			stderr_chunks = j:stderr_result()
			finalize(code)
		end,
	})
	job:start()
	handle = {
		id = job.pid,
		_job = job,
	}
	function handle.cancel()
		if completed then
			return
		end

		job:shutdown(15)

		local active_job = state.active_jobs[handle.id]
		if active_job then
			active_job.cancellation_time = vim.loop.now()
		end

		vim.defer_fn(function()
			if completed then
				return
			end

			job:shutdown(9)
			finalize(-1)
		end, 1000)
	end
	function handle.is_active()
		return not completed
	end

	if timeout then
		vim.defer_fn(function()
			if not completed then
				logger.warn("Tungsten", string.format("Tungsten: job %d timed out after %d ms.", handle.id, timeout))
				handle.cancel()
			end
		end, timeout)
	end

	state.active_jobs[handle.id] = {
		handle = handle,
		bufnr = vim.api.nvim_get_current_buf(),
		cache_key = cache_key,
		code_sent = table.concat(cmd, " "),
		start_time = vim.loop.now(),
	}

	return handle
end

process_queue = function()
	while #job_queue > 0 and active_job_count() < (config.max_jobs or math.huge) do
		local next_job = table.remove(job_queue, 1)
		vim.schedule(function()
			spawn_process(next_job.cmd, next_job.opts)
		end)
	end
end

function M.run_job(cmd, opts)
	local ok, _ = pcall(require, "plenary.job")
	if not ok then
		local msg = "async.run_job: plenary.nvim is required. Install https://github.com/nvim-lua/plenary.nvim."
		logger.error("Tungsten", msg)
		error(msg)
	end
	if active_job_count() >= (config.max_jobs or math.huge) then
		logger.warn("Tungsten", string.format("Maximum of %d jobs reached; queuing job", config.max_jobs))
		table.insert(job_queue, { cmd = cmd, opts = opts })
		return nil
	end
	return spawn_process(cmd, opts)
end

function M.cancel_all_jobs()
	for _, info in pairs(state.active_jobs) do
		if info.handle and info.handle.cancel then
			info.handle.cancel()
		end
	end
end

return M
