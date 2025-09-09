local mock_utils = require("tests.helpers.mock_utils")
local wait_for = require("tests.helpers.wait").wait_for
local spy = require("luassert.spy")
local match = require("luassert.match")

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

		mock_config = { max_jobs = 3 }
		package.loaded["tungsten.config"] = mock_config
		mock_err_handler = {
			notify_error = function() end,
			E_BACKEND_UNAVAILABLE = "E_BACKEND_UNAVAILABLE",
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

		mock_health = {
			check_dependencies = function()
				return {
					wolframscript = { ok = true },
					python = { ok = true },
					matplotlib = { ok = true },
					sympy = { ok = true },
				}
			end,
		}
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

	it("shows and clears a progress indicator", function()
		local ns = vim.api.nvim_create_namespace("tungsten_plot_spinner")

		mock_async.set_callback(function(_, opts)
			vim.defer_fn(function()
				opts.on_exit(0, "done", "")
			end, 10)
		end)

		JobManager.submit({ expression = "sin(x)", bufnr = 0 })

		local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {})
		assert.are.equal(1, #marks)

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
		check_deps_spy = check_deps_spy:call_fake(function()
			return {
				wolframscript = { ok = false, message = "required 13.0+, found none" },
				python = { ok = true },
				matplotlib = { ok = true },
				sympy = { ok = true },
			}
		end)

		local id = JobManager.submit({ expression = "fail", bufnr = 0 })
		assert.is_nil(id)
		assert.spy(check_deps_spy).was.called(1)
		assert.spy(notify_error_spy).was.called(1)
		assert.spy(notify_error_spy).was.called_with("TungstenPlot", "E_BACKEND_UNAVAILABLE", nil, "Missing dependencies: wolframscript none < 13.0")
		assert.are.equal(0, #mock_async.run_job_calls)

		JobManager.submit({ expression = "another", bufnr = 0 })
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
end)
