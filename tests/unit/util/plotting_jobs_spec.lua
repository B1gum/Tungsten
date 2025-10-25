local mock_utils = require("tests.helpers.mock_utils")
local wait_for = require("tests.helpers.wait").wait_for
local spy = require("luassert.spy")
local stub = require("luassert.stub")

describe("Plotting Job Manager", function()
	local JobManager
	local mock_async
	local mock_config
	local mock_err_handler
	local mock_health
	local check_deps_spy
	local notify_error_spy
	local logger_error_spy
	local original_executable

	local modules_to_clear = {
		"tungsten.domains.plotting.job_manager",
		"tungsten.util.async",
		"tungsten.config",
		"tungsten.util.error_handler",
		"tungsten.util.logger",
		"tungsten.util.plotting_io",
		"tungsten.domains.plotting.health",
	}

	before_each(function()
		mock_utils.reset_modules(modules_to_clear)

		original_executable = vim.fn.executable
		vim.fn.executable = function(bin)
			if bin == "wolframscript" then
				return 1
			end
			return original_executable(bin)
		end

		mock_async = {}
		mock_async.run_job_calls = {}
		function mock_async.run_job(cmd, opts)
			table.insert(mock_async.run_job_calls, { cmd, opts })
			if mock_async._callback then
				return mock_async._callback(cmd, opts)
			end
			return mock_async._return
		end
		function mock_async.set_callback(fn)
			mock_async._callback = fn
		end
		function mock_async.set_returns(val)
			mock_async._return = val
		end
		package.loaded["tungsten.util.async"] = mock_async

		mock_config = {
			max_jobs = 3,
			plotting = {
				snippet_width = "0.8\\linewidth",
			},
		}
		package.loaded["tungsten.config"] = mock_config
		mock_err_handler = {
			notify_error = function() end,
			E_BACKEND_UNAVAILABLE = "E_BACKEND_UNAVAILABLE",
			E_UNSUPPORTED_FORM = "E_UNSUPPORTED_FORM",
			E_TIMEOUT = "E_TIMEOUT",
			E_BACKEND_CRASH = "E_BACKEND_CRASH",
			E_CANCELLED = "E_CANCELLED",
		}
		notify_error_spy = spy.on(mock_err_handler, "notify_error")
		package.loaded["tungsten.util.error_handler"] = mock_err_handler
		local logger_stub = {
			debug = function() end,
			error = function() end,
		}
		logger_error_spy = spy.on(logger_stub, "error")
		package.loaded["tungsten.util.logger"] = logger_stub
		package.loaded["tungsten.util.plotting_io"] = {
			find_math_block_end = function()
				return 0
			end,
		}

		mock_health = {}
		function mock_health.check_dependencies(cb)
			if cb then
				cb({
					wolframscript = { ok = true },
					python = { ok = true },
					matplotlib = { ok = true },
					sympy = { ok = true },
				})
			end
		end
		check_deps_spy = spy.on(mock_health, "check_dependencies")
		package.loaded["tungsten.domains.plotting.health"] = mock_health

		JobManager = require("tungsten.domains.plotting.job_manager")
		local ns = vim.api.nvim_create_namespace("tungsten_plot_spinner")
		vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
	end)

	after_each(function()
		check_deps_spy:clear()
		notify_error_spy:clear()
		logger_error_spy:clear()
		local ns = vim.api.nvim_create_namespace("tungsten_plot_spinner")
		vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
		vim.fn.executable = original_executable
		mock_utils.reset_modules(modules_to_clear)
	end)

	it("runs plot jobs asynchronously and invokes callbacks", function()
		local success_called, success_arg = false, nil
		local error_called = false

		local function on_success(arg)
			success_called = true
			success_arg = arg
		end

		local function on_error()
			error_called = true
		end

		JobManager.submit({ expression = "x^2", bufnr = 0 }, on_success, on_error)

		assert.are.equal(1, #mock_async.run_job_calls)
		local opts = mock_async.run_job_calls[1][2]
		opts.on_exit(0, "plot.png", "")

		assert.is_true(success_called)
		assert.are.equal("plot.png", success_arg)
		assert.is_false(error_called)
	end)

	it("notifies cancellation without invoking user error callback multiple times", function()
		notify_error_spy:clear()
		local error_call_count = 0
		local received_err

		local function on_error(err)
			error_call_count = error_call_count + 1
			received_err = err
		end

		JobManager.submit({ expression = "x^2", bufnr = 0 }, nil, on_error)
		assert.are.equal(1, #mock_async.run_job_calls)
		local opts = mock_async.run_job_calls[1][2]
		opts.on_exit(-1, "", "")

		assert.are.equal(1, error_call_count)
		assert.is_table(received_err)
		assert.are.equal(-1, received_err.code)
		assert.is_true(received_err.cancelled)
		assert.spy(notify_error_spy).was.called(1)
		assert.spy(notify_error_spy).was.called_with("TungstenPlot", mock_err_handler.E_CANCELLED)
	end)

	it("queues jobs beyond the concurrency limit in FIFO order", function()
		mock_config.max_jobs = 1
		local order = {}

		mock_async.set_callback(function(cmd, opts)
			vim.schedule(function()
				table.insert(order, cmd.expression)
				opts.on_exit(0, "ok", "")
			end)
		end)

		JobManager.submit({ expression = "job1", bufnr = 0 })
		JobManager.submit({ expression = "job2", bufnr = 0 })
		JobManager.submit({ expression = "job3", bufnr = 0 })
		wait_for(function()
			return #order == 3
		end, 500)
		assert.are.same({ "job1", "job2", "job3" }, order)
	end)

	it("caps concurrent jobs at three even when configured higher", function()
		mock_config.max_jobs = 10
		local callbacks = {}

		mock_async.set_callback(function(cmd, opts)
			table.insert(callbacks, { cmd = cmd, opts = opts })
		end)

		JobManager.submit({ expression = "job1", bufnr = 0 })
		JobManager.submit({ expression = "job2", bufnr = 0 })
		JobManager.submit({ expression = "job3", bufnr = 0 })
		JobManager.submit({ expression = "job4", bufnr = 0 })

		assert.are.equal(3, #mock_async.run_job_calls)

		callbacks[1].opts.on_exit(0, "ok", "")

		wait_for(function()
			return #mock_async.run_job_calls == 4
		end, 500)
	end)

	it("submissions return immediately while waiting for dependency checks", function()
		check_deps_spy:clear()
		local dependency_cb
		mock_health.check_dependencies = function(cb)
			dependency_cb = cb
		end
		check_deps_spy = spy.on(mock_health, "check_dependencies")

		local id = JobManager.submit({ expression = "pending", bufnr = 0 })
		assert.is_not_nil(id)
		assert.spy(check_deps_spy).was.called(1)
		assert.are.equal(0, #mock_async.run_job_calls)

		dependency_cb({
			wolframscript = { ok = true },
			python = { ok = true },
			matplotlib = { ok = true },
			sympy = { ok = true },
		})

		wait_for(function()
			return #mock_async.run_job_calls == 1
		end, 500)
	end)

	it("shows and clears a progress indicator", function()
		local ns = vim.api.nvim_create_namespace("tungsten_plot_spinner")

		mock_async.set_callback(function(_, opts)
			vim.defer_fn(function()
				opts.on_exit(0, "done", "")
			end, 200)
		end)

		JobManager.submit({ expression = "sin(x)", bufnr = 0 })

		local function current_frame()
			local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
			if #marks == 0 then
				return nil
			end
			local details = marks[1][4]
			if details and details.virt_text and details.virt_text[1] then
				return details.virt_text[1][1]
			end
			return nil
		end

		wait_for(function()
			return current_frame() ~= nil
		end, 200)

		local first_frame = current_frame()
		assert.is_not_nil(first_frame)

		wait_for(function()
			local frame = current_frame()
			return frame and frame ~= first_frame
		end, 500)

		wait_for(function()
			return #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}) == 0
		end, 500)
	end)

	it("cancels a running job", function()
		local handle_cancelled = false
		local handle = {
			cancel = function()
				handle_cancelled = true
			end,
		}
		mock_async.set_returns(handle)

		local id = JobManager.submit({ expression = "x^3", bufnr = 0 })
		local ok = JobManager.cancel(id)

		assert.is_true(ok)
		assert.is_true(handle_cancelled)
	end)

	it("cancels a deferred job queued by the async runner", function()
		local on_exit_spy

		mock_async.set_callback(function(_, opts)
			local original_on_exit = opts.on_exit
			on_exit_spy = spy.new(function(code, stdout, stderr)
				original_on_exit(code, stdout, stderr)
			end)
			opts.on_exit = on_exit_spy

			local handle = {}
			function handle.cancel()
				opts.on_exit(-1, "", "")
			end
			function handle.is_active()
				return true
			end
			return handle
		end)

		local id = JobManager.submit({ expression = "queued", bufnr = 0 })

		assert.is_table(JobManager.active_jobs[id])
		assert.is_table(JobManager.active_jobs[id].handle)

		local ok = JobManager.cancel(id)

		assert.is_true(ok)

		wait_for(function()
			return JobManager.active_jobs[id] == nil
		end, 500)

		assert.spy(on_exit_spy).was.called(1)
		assert.spy(on_exit_spy).was.called_with(-1, "", "")
	end)

	it("cancel_all removes deferred jobs before they spawn", function()
		local exit_spies = {}

		mock_async.set_callback(function(_, opts)
			local original_on_exit = opts.on_exit
			local on_exit_spy = spy.new(function(code, stdout, stderr)
				original_on_exit(code, stdout, stderr)
			end)
			table.insert(exit_spies, on_exit_spy)
			opts.on_exit = on_exit_spy

			local handle = {}
			function handle.cancel()
				opts.on_exit(-1, "", "")
			end
			function handle.is_active()
				return true
			end
			return handle
		end)

		local first = JobManager.submit({ expression = "job-a", bufnr = 0 })
		local second = JobManager.submit({ expression = "job-b", bufnr = 0 })

		assert.is_table(JobManager.active_jobs[first])
		assert.is_table(JobManager.active_jobs[second])

		JobManager.cancel_all()

		wait_for(function()
			return vim.tbl_count(JobManager.active_jobs) == 0
		end, 500)

		for _, exit_spy in ipairs(exit_spies) do
			assert.spy(exit_spy).was.called(1)
			assert.spy(exit_spy).was.called_with(-1, "", "")
		end
	end)

	it("cancels all jobs and cleans up queued temp files", function()
		mock_config.max_jobs = 1
		local handle_cancelled = false
		local handle = {
			cancel = function()
				handle_cancelled = true
			end,
		}
		mock_async.set_returns(handle)

		JobManager.submit({ expression = "active", bufnr = 0 })

		local tmp = vim.fn.tempname()
		vim.fn.writefile({ "tmp" }, tmp)
		JobManager.submit({ temp_file = tmp, bufnr = 0 })

		JobManager.cancel_all()

		assert.is_true(handle_cancelled)
		assert.is_nil(vim.loop.fs_stat(tmp))
	end)

	it("checks dependencies only once before submitting jobs", function()
		JobManager.submit({ expression = "a", bufnr = 0 })
		JobManager.submit({ expression = "b", bufnr = 0 })
		assert.spy(check_deps_spy).was.called(1)
	end)

	it("aborts submission when dependencies are missing", function()
		check_deps_spy:clear()
		local dependency_cb
		mock_health.check_dependencies = function(cb)
			dependency_cb = cb
		end
		check_deps_spy = spy.on(mock_health, "check_dependencies")

		local id = JobManager.submit({ expression = "fail", bufnr = 0 })
		assert.is_not_nil(id)
		assert.spy(check_deps_spy).was.called(1)
		assert.are.equal(0, #mock_async.run_job_calls)

		dependency_cb({
			wolframscript = { ok = false, message = "required 13.0+, found none" },
			python = { ok = true },
			matplotlib = { ok = true },
			sympy = { ok = true },
		})

		assert.spy(notify_error_spy).was.called(1)
		assert
			.spy(notify_error_spy).was
			.called_with("TungstenPlot", "E_BACKEND_UNAVAILABLE", nil, "Missing dependencies: wolframscript none < 13.0")
		assert.are.equal(0, #mock_async.run_job_calls)

		local second = JobManager.submit({ expression = "another", bufnr = 0 })
		assert.is_nil(second)
		assert.spy(check_deps_spy).was.called(1)
	end)

	it("raises backend unavailable when wolframscript missing", function()
		vim.fn.executable = function()
			return 0
		end
		check_deps_spy:clear()
		local id = JobManager.submit({ expression = "nope", bufnr = 0 })
		assert.is_nil(id)
		assert.spy(check_deps_spy).was_not_called()
		assert.spy(notify_error_spy).was.called(1)
		assert
			.spy(notify_error_spy).was
			.called_with("TungstenPlot", mock_err_handler.E_BACKEND_UNAVAILABLE .. ": Install Wolfram or configure Python backend")
	end)

	it("submits vertical functions with Wolfram backend", function()
		local id = JobManager.submit({
			expression = "expr",
			bufnr = 0,
			backend = "wolfram",
			form = "explicit",
			dim = 2,
			series = { { dependent_vars = { "x" } } },
		})
		assert.is_not_nil(id)
		assert.are.equal(1, #mock_async.run_job_calls)
		assert.spy(notify_error_spy).was_not_called()
	end)

	it("returns E_UNSUPPORTED_FORM for vertical functions with Python backend", function()
		local id = JobManager.submit({
			expression = "expr",
			bufnr = 0,
			backend = "python",
			form = "explicit",
			dim = 2,
			series = { { dependent_vars = { "x" } } },
		})
		assert.is_nil(id)
		assert.spy(notify_error_spy).was.called(1)
		assert.spy(notify_error_spy).was.called_with("TungstenPlot", mock_err_handler.E_UNSUPPORTED_FORM)
		assert.are.equal(0, #mock_async.run_job_calls)
	end)

	it("returns E_UNSUPPORTED_FORM when backend cannot handle inequalities", function()
		local id = JobManager.submit({
			expression = "expr",
			bufnr = 0,
			backend = "python",
			form = "implicit",
			dim = 2,
			series = { { kind = "inequality", dependent_vars = {} } },
		})
		assert.is_nil(id)
		assert.spy(notify_error_spy).was.called(1)
		assert.spy(notify_error_spy).was.called_with("TungstenPlot", mock_err_handler.E_UNSUPPORTED_FORM)
		assert.are.equal(0, #mock_async.run_job_calls)
	end)

	it("falls back to the selection end without notifying when the math block is unterminated", function()
		local original_notify = vim.notify
		local notify_spy = spy.new(function() end)
		vim.notify = notify_spy

		package.loaded["tungsten.util.plotting_io"].find_math_block_end = function()
			return nil
		end

		local bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "line1", "line2", "line3", "line4" })
		local set_lines_stub = stub(vim.api, "nvim_buf_set_lines")

		local function cleanup()
			mock_async.set_callback(nil)
			if set_lines_stub then
				set_lines_stub:revert()
			end
			if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
				vim.api.nvim_buf_delete(bufnr, { force = true })
			end
			vim.notify = original_notify
		end

		local ok, err = pcall(function()
			mock_async.set_callback(function(_, opts)
				opts.on_exit(0, "/tmp/plot.png", "")
			end)

			JobManager.submit({
				expression = "expr",
				bufnr = bufnr,
				outputmode = "latex",
				start_line = 1,
				end_line = 3,
			})

			assert.spy(notify_spy).was_not_called()

			assert.stub(set_lines_stub).was.called(1)
			local args = set_lines_stub.calls[1].vals
			assert.are.equal(bufnr, args[1])
			assert.are.equal(4, args[2])
			assert.are.equal(4, args[3])
			assert.is_table(args[5])
			assert.are.equal(1, #args[5])
			local snippet = args[5][1]
			assert.is_truthy(snippet:find("includegraphics", 1, true))
			assert.is_truthy(snippet:find("0.8", 1, true))
		end)

		cleanup()

		if not ok then
			error(err)
		end
	end)

	it("returns E_UNSUPPORTED_FORM when backend cannot handle classification", function()
		local id = JobManager.submit({
			expression = "expr",
			bufnr = 0,

			backend = "python",
			form = "implicit",
			dim = 3,
			series = { { dependent_vars = {} } },
		})
		assert.is_nil(id)
		assert.spy(notify_error_spy).was.called(1)
		assert.spy(notify_error_spy).was.called_with("TungstenPlot", mock_err_handler.E_UNSUPPORTED_FORM)
		assert.are.equal(0, #mock_async.run_job_calls)
	end)
end)
