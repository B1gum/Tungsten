-- lua/tungsten/util/async.lua
-- Utilities for spawning external processes asynchronously.

local state = require("tungsten.state")
local logger = require("tungsten.util.logger")
local config = require("tungsten.config")

local M = {}

local job_queue = {}
local process_queue

local function remove_from_queue(proxy)
	for index, entry in ipairs(job_queue) do
		if entry.handle == proxy then
			table.remove(job_queue, index)
			return true
		end
	end
	return false
end

local function attach_real_handle(proxy, real_handle)
	if not proxy then
		return
	end

	proxy._real = real_handle
	proxy._queued = false
	proxy._opts = nil
	if real_handle and real_handle.id then
		proxy.id = real_handle.id
	end

	if proxy._pending_cancel then
		proxy._pending_cancel = nil
		if real_handle and real_handle.cancel then
			real_handle.cancel()
		end
	end
end

local function create_proxy_handle(opts)
	local proxy = {
		_queued = true,
		_opts = opts,
	}

	function proxy.cancel()
		if proxy._real then
			if proxy._real.cancel then
				proxy._real.cancel()
			end
			return
		end

		local removed = remove_from_queue(proxy)
		if removed then
			proxy._queued = false
			local pending_opts = proxy._opts
			proxy._opts = nil
			if pending_opts and pending_opts.on_exit then
				local on_exit = pending_opts.on_exit
				vim.schedule(function()
					on_exit(-1, "", "")
				end)
			end
			return
		end

		proxy._pending_cancel = true
	end

	function proxy.is_active()
		if proxy._real and proxy._real.is_active then
			return proxy._real.is_active()
		end
		return proxy._queued and not proxy._pending_cancel
	end

	return proxy
end

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
			local handle = spawn_process(next_job.cmd, next_job.opts)
			attach_real_handle(next_job.handle, handle)
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
		local proxy = create_proxy_handle(opts)
		table.insert(job_queue, { cmd = cmd, opts = opts, handle = proxy })
		return proxy
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
