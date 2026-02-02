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
					on_exit(-1, "", "", { cancel_reason = "cancelled" })
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
			timed_out = false,
			timeout_ms = nil,
			cancel_reason = nil,
		},
	}

	function handle.cancel(reason)
		if handle._state.completed then
			return
		end

		if reason and handle._state.cancel_reason == nil then
			handle._state.cancel_reason = reason
		elseif handle._state.cancel_reason == nil then
			handle._state.cancel_reason = "cancelled"
		end

		if handle._state.cancel_reason == "timeout" then
			handle._state.timed_out = true
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
				local exit_code = handle._state.timed_out and 124 or -1
				handle._state.finalize(exit_code)
			end
		end, 1000)
	end
	function handle.is_active()
		return not handle._state.completed
	end

	return handle
end

local function setup_timeout(handle, timeout_ms)
	local normalized = tonumber(timeout_ms)
	if not normalized or normalized <= 0 then
		return
	end

	handle._state.timeout_ms = normalized

	vim.defer_fn(function()
		if handle.is_active() then
			handle._state.timed_out = true
			handle._state.cancel_reason = "timeout"
			logger.warn("Tungsten", string.format("Tungsten: job %d timed out after %d ms.", handle.id, normalized))
			handle.cancel("timeout")
		end
	end, normalized)
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
		local meta = {
			timed_out = handle._state.timed_out or false,
			timeout_ms = handle._state.timeout_ms,
			cancel_reason = handle._state.cancel_reason,
		}
		vim.schedule(function()
			handle._state.on_exit(exit_code, stdout, stderr, meta)
		end)
	end
end

local function resolve_timeout_ms(opts)
	if not opts then
		return nil
	end
	if opts.timeout ~= nil then
		return opts.timeout
	end
	if opts.timeout_ms ~= nil then
		return opts.timeout_ms
	end
	return nil
end

local function spawn_process(cmd, opts)
	opts = opts or {}
	local _ = process_queue
	local cache_key = opts.cache_key
	local on_exit = opts.on_exit or opts.on_complete
	local timeout = resolve_timeout_ms(opts)
	if timeout == nil then
		timeout = config.timeout_ms
	end
	if timeout == nil then
		timeout = config.process_timeout_ms
	end
	if timeout == nil then
		timeout = 10000
	end

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
	opts = opts or {}
	self.buffer = {}
	self.queue = {}
	self.busy = false
	self.current_request = nil
	self.delimiter = opts.delimiter or "__TUNGSTEN_END__"
	self.ready = false
	self.dead = false
	self.last_error = nil
	self._timeout_token = nil

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

					self:_finish_current(result, nil)

					if not self.ready then
						self.ready = true
						logger.info("Tungsten", "Persistent session ready.")
					end
				else
					table.insert(self.buffer, line)
				end
			elseif err then
				self:_finish_current(nil, err)
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

function PersistentJob:is_dead()
	return self.dead
end

function PersistentJob:_finish_current(result, err)
	local current = self.current_request
	self.current_request = nil
	self.buffer = {}

	if self._timeout_token then
		self._timeout_token.active = false
		self._timeout_token = nil
	end

	if current and current.callback then
		local cb = current.callback
		vim.schedule(function()
			cb(result, err)
		end)
	end

	self.busy = false
	self:process_queue()
end

function PersistentJob:_cancel_queued(cancel_error)
	if #self.queue == 0 then
		return
	end
	local pending = self.queue
	self.queue = {}
	for _, item in ipairs(pending) do
		if item.callback then
			local err_msg = item.cancel_error or cancel_error
			vim.schedule(function()
				item.callback(nil, err_msg)
			end)
		end
	end
end

function PersistentJob:_handle_timeout(item, timeout_ms)
	self.dead = true
	self.busy = false
	self.current_request = nil
	self.buffer = {}
	if self._timeout_token then
		self._timeout_token.active = false
		self._timeout_token = nil
	end

	local timeout_err = (item and item.timeout_error) or "E_TIMEOUT: persistent session timed out."
	self.last_error = timeout_err

	if self.job then
		self.job:shutdown()
	end

	logger.warn("Tungsten", string.format("Persistent session timed out after %d ms.", timeout_ms))

	if item and item.callback then
		vim.schedule(function()
			item.callback(nil, timeout_err)
		end)
	end

	self:_cancel_queued(timeout_err)
end

function PersistentJob:_start_timeout(item)
	local timeout_ms = item and item.timeout_ms
	local normalized = tonumber(timeout_ms)
	if not normalized or normalized <= 0 then
		return
	end

	local token = { active = true }
	self._timeout_token = token
	vim.defer_fn(function()
		if not token.active then
			return
		end
		if self.current_request ~= item then
			return
		end
		token.active = false
		self:_handle_timeout(item, normalized)
	end, normalized)
end

function PersistentJob:send(input, callback, opts)
	if self.dead then
		if callback then
			local err_msg = self.last_error
				or (opts and opts.timeout_error)
				or (opts and opts.cancel_error)
				or "E_CANCELLED: persistent session reset."
			vim.schedule(function()
				callback(nil, err_msg)
			end)
		end
		return
	end

	opts = opts or {}
	table.insert(self.queue, {
		input = input,
		callback = callback,
		timeout_ms = opts.timeout_ms or opts.timeout,
		timeout_error = opts.timeout_error,
		cancel_error = opts.cancel_error,
	})
	self:process_queue()
end

function PersistentJob:process_queue()
	if self.busy or #self.queue == 0 then
		return
	end

	local item = table.remove(self.queue, 1)
	self.current_request = item
	self.busy = true
	self.job:send(item.input .. "\n")
	self:_start_timeout(item)
end

function PersistentJob:stop()
	if self.job then
		self.job:shutdown()
	end
	if self._timeout_token then
		self._timeout_token.active = false
		self._timeout_token = nil
	end
	self.dead = true
end

function M.create_persistent_job(cmd, opts)
	return PersistentJob.new(cmd, opts)
end

return M
