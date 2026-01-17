local mock_utils = require("tests.helpers.mock_utils")
local spy = require("luassert.spy")

describe("Plotting job queue", function()
	local queue
	local dependencies
	local backends
	local cleanup
	local error_handler
	local dep_ready_cb

	local function reset_modules()
		mock_utils.reset_modules({
			"tungsten.domains.plotting.job_manager.queue",
			"tungsten.config",
			"tungsten.util.logger",
			"tungsten.util.async",
			"tungsten.util.error_handler",
			"tungsten.domains.plotting.errors",
			"tungsten.domains.plotting.io",
			"tungsten.domains.plotting.job_manager.cleanup",
			"tungsten.domains.plotting.job_manager.dependencies",
			"tungsten.domains.plotting.job_manager.spinner",
			"tungsten.domains.plotting.backends",
		})
	end

	local function setup_mocks()
		package.loaded["tungsten.config"] = {
			max_jobs = 0,
			plotting = { backend = "demo", snippet_width = "1\\linewidth" },
			backend_opts = { wolfram = { wolfram_path = "wolframscript" } },
		}

		package.loaded["tungsten.util.logger"] = { debug = function() end }
		package.loaded["tungsten.util.async"] = {
			run_job = function()
				return { cancel = function() end }
			end,
		}

		error_handler = {
			notify_error = spy.new(function() end),
			E_UNSUPPORTED_FORM = "unsupported",
			E_BACKEND_UNAVAILABLE = "unavailable",
			E_VIEWER_FAILED = "viewer_failed",
		}
		package.loaded["tungsten.util.error_handler"] = error_handler

		package.loaded["tungsten.domains.plotting.errors"] = {
			normalize_job_error = function(err)
				return err or "default", nil, nil
			end,
		}
		package.loaded["tungsten.domains.plotting.io"] = { find_math_block_end = function() end }

		cleanup = {
			cleanup_temp = spy.new(function() end),
			notify_job_cancelled = spy.new(function() end),
		}
		package.loaded["tungsten.domains.plotting.job_manager.cleanup"] = cleanup

		dependencies = {
			has_dependency_report = function()
				return true
			end,
			get_backend_status = function()
				return true
			end,
			notify_backend_failure = spy.new(function() end),
			on_dependencies_ready = function(cb)
				dep_ready_cb = cb
			end,
		}
		package.loaded["tungsten.domains.plotting.job_manager.dependencies"] = dependencies

		package.loaded["tungsten.domains.plotting.job_manager.spinner"] = {
			start_spinner = function()
				return nil, nil, nil
			end,
		}

		backends = {
			is_supported = function()
				return true
			end,
		}
		package.loaded["tungsten.domains.plotting.backends"] = backends
	end

	before_each(function()
		reset_modules()
		dep_ready_cb = nil
		setup_mocks()
		queue = require("tungsten.domains.plotting.job_manager.queue")
		queue.reset_state()
	end)

	after_each(function()
		reset_modules()
	end)

	it("rejects unsupported backend combinations", function()
		backends.is_supported = function()
			return false
		end

		local id = queue.submit({ form = "explicit", dim = 2, backend = "demo" })
		assert.is_nil(id)
		assert.spy(error_handler.notify_error).was.called_with("TungstenPlot", error_handler.E_UNSUPPORTED_FORM)
	end)

	it("queues pending jobs when dependencies are ready", function()
		local opts = {
			form = "explicit",
			dim = 2,
			backend = "demo",
			xrange = { 0, 1 },
			expression = "x",
		}
		local id = queue.submit(opts)
		assert.are.equal(1, id)

		local snapshot = queue.get_queue_snapshot()
		assert.are.equal(0, #snapshot.active)
		assert.are.equal(1, #snapshot.pending)
		assert.are.equal(id, snapshot.pending[1].id)
		assert.are.same({ 0, 1 }, snapshot.pending[1].ranges.xrange)
		assert.are_not.equal(opts.xrange, snapshot.pending[1].ranges.xrange)
	end)

	it("defers jobs until dependencies are resolved", function()
		dependencies.has_dependency_report = function()
			return false
		end

		local id = queue.submit({ form = "explicit", dim = 2, backend = "demo" })
		assert.are.equal(1, id)
		assert.is_not_nil(dep_ready_cb)

		local snapshot = queue.get_queue_snapshot()
		assert.are.equal(0, #snapshot.pending)

		dep_ready_cb()
		snapshot = queue.get_queue_snapshot()
		assert.are.equal(1, #snapshot.pending)
	end)

	it("cancels active jobs via handles", function()
		local cancel_spy = spy.new(function() end)
		queue.active_jobs[5] = { handle = { cancel = cancel_spy } }

		assert.is_true(queue.cancel(5))
		assert.spy(cancel_spy).was.called(1)
		assert.is_true(queue.active_jobs[5].cancelled)
	end)

	it("cancels queued and pending dependency jobs", function()
		local queued_id = queue.submit({ form = "explicit", dim = 2, backend = "demo" })
		assert.is_true(queue.cancel(queued_id))
		assert.spy(cleanup.notify_job_cancelled).was.called(1)
		assert.are.equal(0, #queue.get_queue_snapshot().pending)

		dependencies.has_dependency_report = function()
			return false
		end
		local pending_id = queue.submit({ form = "explicit", dim = 2, backend = "demo" })
		assert.is_true(queue.cancel(pending_id))
		assert.spy(cleanup.notify_job_cancelled).was.called(2)
	end)
end)
