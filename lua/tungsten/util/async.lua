-- lua/tungsten/util/async.lua
-- Utilities for spawning external processes asynchronously.

local state = require("tungsten.state")
local logger = require("tungsten.util.logger")
local config = require("tungsten.config")

local M = {}

local active_job_count

local JobQueue = {}
JobQueue.__index = JobQueue

function JobQueue.new()
	return setmetatable({ items = {} }, JobQueue)
end

function JobQueue:enqueue(cmd, opts, handle)
	table.insert(self.items, { cmd = cmd, opts = opts, handle = handle })
end

function JobQueue:pop()
	if #self.items == 0 then
		return nil
	end
	return table.remove(self.items, 1)
end

function JobQueue:remove(handle_proxy)
	for index, entry in ipairs(self.items) do
		if entry.handle == handle_proxy then
			table.remove(self.items, index)
			return true
		end
	end
	return false
end

function JobQueue:is_full(limit)
	local _ = self
	local max_jobs = limit or math.huge
	return active_job_count() >= max_jobs
end

local job_queue = JobQueue.new()
local process_queue

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

		local removed = job_queue:remove(proxy)
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

active_job_count = function()
	local n = 0
	for _ in pairs(state.active_jobs) do
		n = n + 1
	end
	return n
end

local function replace_table(target, source)
	for index = #target, 1, -1 do
		target[index] = nil
	end
	for _, value in ipairs(source) do
		table.insert(target, value)
	end
end

local function create_plenary_job(cmd, stdout_table, stderr_table, on_exit_callback)
	local Job = require("plenary.job")
	local job = Job:new({
		command = cmd[1],
		args = vim.list_slice(cmd, 2),
		enable_recording = true,
		on_stdout = function(_, line)
			if line then
				table.insert(stdout_table, line)
			end
		end,
		on_stderr = function(_, line)
			if line then
				table.insert(stderr_table, line)
			end
		end,
		on_exit = function(j, code)
			replace_table(stdout_table, j:result())
			replace_table(stderr_table, j:stderr_result())
			if on_exit_callback then
				on_exit_callback(code)
			end
		end,
	})
	job:start()
	return job
end

local function create_job_handle(pid, job_obj)
	local handle = {
		id = pid,
		_job = job_obj,
		_state = {
			completed = false,
			finalize = nil,
			on_exit = nil,
		},
	}

	function handle.cancel()
		if handle._state.completed then
			return
		end

		job_obj:shutdown(15)

		local active_job = state.active_jobs[handle.id]
		if active_job then
			active_job.cancellation_time = vim.loop.now()
		end

		vim.defer_fn(function()
			if handle._state.completed then
				return
			end

			job_obj:shutdown(9)
			if handle._state.finalize then
				handle._state.finalize(-1)
			end
		end, 1000)
	end
	function handle.is_active()
		return not handle._state.completed
	end

	return handle
end

local function setup_timeout(handle, timeout_ms)
	if not timeout_ms then
		return
	end

	vim.defer_fn(function()
		if handle.is_active() then
			logger.warn("Tungsten", string.format("Tungsten: job %d timed out after %d ms.", handle.id, timeout_ms))
			handle.cancel()
		end
	end, timeout_ms)
end

local function finalize_job(handle, exit_code, stdout_chunks, stderr_chunks)
	if handle._state.completed then
		return
	end
	handle._state.completed = true

	if handle and handle.id and state.active_jobs[handle.id] then
		state.active_jobs[handle.id] = nil
	end

	process_queue()

	if handle._state.on_exit then
		local stdout = table.concat(stdout_chunks, "\n"):gsub("^%s*(.-)%s*$", "%1")
		local stderr = table.concat(stderr_chunks, "\n"):gsub("^%s*(.-)%s*$", "%1")
		vim.schedule(function()
			handle._state.on_exit(exit_code, stdout, stderr)
		end)
	end
end

local function spawn_process(cmd, opts)
	opts = opts or {}
	local _ = process_queue
	local cache_key = opts.cache_key
	local on_exit = opts.on_exit or opts.on_complete
	local timeout = opts.timeout or config.process_timeout_ms or 10000

	local stdout_chunks, stderr_chunks = {}, {}

	local handle
	local function on_job_exit(code)
		finalize_job(handle, code, stdout_chunks, stderr_chunks)
	end

	local job = create_plenary_job(cmd, stdout_chunks, stderr_chunks, on_job_exit)
	handle = create_job_handle(job.pid, job)
	handle._state.finalize = on_job_exit
	handle._state.on_exit = on_exit

	setup_timeout(handle, timeout)

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
	while true do
		if job_queue:is_full(config.max_jobs) then
			return
		end

		local next_job = job_queue:pop()
		if not next_job then
			return
		end

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
	if job_queue:is_full(config.max_jobs) then
		logger.warn("Tungsten", string.format("Maximum of %d jobs reached; queuing job", config.max_jobs))
		local proxy = create_proxy_handle(opts)
		job_queue:enqueue(cmd, opts, proxy)
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

local PersistentJob = {}
PersistentJob.__index = PersistentJob

function PersistentJob.new(cmd, opts)
	local self = setmetatable({}, PersistentJob)
	self.buffer = {}
	self.queue = {}
	self.busy = false
	self.current_callback = nil
	self.delimiter = opts.delimiter or "__TUNGSTEN_END__"
	self.ready = false

	local Job = require("plenary.job")
	self.job = Job:new({
		command = cmd[1],
		args = vim.list_slice(cmd, 2),
		interactive = true,
		on_stdout = function(err, line)
			if line then
				if line:find(self.delimiter, 1, true) then
					local result = table.concat(self.buffer, "\n")
					self.buffer = {}

					if self.current_callback then
						local cb = self.current_callback
						self.current_callback = nil
						vim.schedule(function()
							cb(result, nil)
						end)
					end

					if not self.ready then
						self.ready = true
						logger.info("Tungsten", "Persistent session ready.")
					end

					self.busy = false
					self:process_queue()
				else
					table.insert(self.buffer, line)
				end
			elseif err then
				vim.schedule(function()
					if self.current_callback then
						self.current_callback(nil, err)
						self.current_callback = nil
					end
					self.busy = false
				end)
			end
		end,
		on_stderr = function(_, line)
			if line and line ~= "" then
				logger.debug("Tungsten Persistent Stderr", line)
			end
		end,
	})

	self.job:start()
	return self
end

function PersistentJob:send(input, callback)
	table.insert(self.queue, { input = input, callback = callback })
	self:process_queue()
end

function PersistentJob:process_queue()
	if self.busy or #self.queue == 0 then
		return
	end

	local item = table.remove(self.queue, 1)
	self.current_callback = item.callback
	self.busy = true
	self.job:send(item.input .. "\n")
end

function PersistentJob:stop()
	if self.job then
		self.job:shutdown()
	end
end

function M.create_persistent_job(cmd, opts)
	return PersistentJob.new(cmd, opts)
end

return M
