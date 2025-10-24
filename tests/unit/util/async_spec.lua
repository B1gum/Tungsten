-- tests/unit/util/async_spec.lua
-- Unit tests for tungsten.util.async.run_job

local async = require("tungsten.util.async")
local state = require("tungsten.state")

local function clear_active_jobs()
	for k in pairs(state.active_jobs) do
		state.active_jobs[k] = nil
	end
end

local wait_for = require("tests.helpers.wait").wait_for

describe("tungsten.util.async.run_job", function()
	vim.wait(10)
	before_each(function()
		clear_active_jobs()
	end)

	it("runs command successfully and captures stdout", function()
		local result
		local handle = async.run_job({ "sh", "-c", "sleep 0.1; printf ok" }, {
			cache_key = "ok",
			timeout = 1000,
			on_exit = function(code, out, err)
				result = { code = code, out = out, err = err }
			end,
		})
		assert.truthy(state.active_jobs[handle.id])
		wait_for(function()
			return result
		end)
		assert.are.equal(0, result.code)
		assert.are.equal("ok", result.out)
		assert.are.equal("", result.err)
		assert.falsy(state.active_jobs[handle.id])
	end)

	it("handles non-zero exit code and stderr", function()
		local result
		local handle = async.run_job({ "sh", "-c", "printf fail 1>&2; exit 3" }, {
			cache_key = "fail",
			timeout = 1000,
			on_exit = function(code, out, err)
				result = { code = code, out = out, err = err }
			end,
		})
		wait_for(function()
			return result
		end)
		assert.are.equal(3, result.code)
		assert.are.equal("", result.out)
		assert.are.equal("fail", result.err)
		assert.falsy(state.active_jobs[handle.id])
	end)

	it("terminates on timeout", function()
		local result
		local handle = async.run_job({ "sh", "-c", "sleep 2" }, {
			cache_key = "timeout",
			timeout = 100,
			on_exit = function(code, out, err)
				result = { code = code, out = out, err = err }
			end,
		})
		wait_for(function()
			return result
		end, 1000)
		assert.is_true(result.code ~= 0)
		assert.falsy(state.active_jobs[handle.id])
	end)

	it("cancel_all_jobs terminates running jobs", function()
		local done = false
		local handle = async.run_job({ "sh", "-c", "sleep 2" }, {
			cache_key = "bulk",
			timeout = 1000,
			on_exit = function()
				done = true
			end,
		})
		vim.defer_fn(function()
			async.cancel_all_jobs()
		end, 100)
		wait_for(function()
			return done
		end, 1000)
		assert.falsy(state.active_jobs[handle.id])
	end)

	it("sends TERM then KILL when canceling a stuck job", function()
		local original_job = package.loaded["plenary.job"]
		local exit_cb
		local signals = {}

		local JobMock = {}
		function JobMock:new(opts)
			exit_cb = opts.on_exit
			local job_instance
			job_instance = {
				pid = 4242,
				start = function(_) end,
				shutdown = function(_, signal)
					table.insert(signals, signal)
					if signal == 9 and exit_cb then
						exit_cb(job_instance, -1)
					end
				end,
				result = function()
					return {}
				end,
				stderr_result = function()
					return {}
				end,
			}
			return job_instance
		end

		package.loaded["plenary.job"] = JobMock

		local handle = async.run_job({ "fake", "command" }, {
			cache_key = "stuck",
			timeout = nil,
			on_exit = function() end,
		})

		assert.is_not_nil(handle)
		assert.are.same(0, #signals)

		handle.cancel()

		local info = state.active_jobs[handle.id]
		assert.is_not_nil(info)
		assert.is_number(info.cancellation_time)

		wait_for(function()
			return signals[2] == 9 and state.active_jobs[handle.id] == nil
		end, 1500)

		assert.are.same(15, signals[1])
		assert.are.same(9, signals[2])

		package.loaded["plenary.job"] = original_job
	end)
end)
