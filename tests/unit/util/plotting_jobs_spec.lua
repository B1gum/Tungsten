-- Unit tests for the plotting job management logic.

local spy = require("luassert.spy")
local match = require("luassert.match")
local mock_utils = require("tests.helpers.mock_utils")
local wait_for = require("tests.helpers.wait").wait_for

describe("Plotting Job Management", function()
	local PlottingJobManager
	local mock_async
	local mock_state
	local mock_config
	local mock_status_ui
	local mock_temp_file_manager

	local original_require

	local modules_to_clear = {
		"tungsten.plotting.job_manager",
		"tungsten.util.async",
		"tungsten.state",
		"tungsten.config",
		"tungsten.ui.virtual_result",
		"tungsten.util.temp_files",
	}

	before_each(function()
		mock_utils.reset_modules(modules_to_clear)

		mock_async = mock_utils.create_empty_mock_module("tungsten.util.async", { "run_job", "cancel_all_jobs" })
		mock_state = { active_jobs = {} }
		mock_config = { max_jobs = 3 }
		mock_status_ui = mock_utils.create_empty_mock_module("tungsten.ui.virtual_result", { "show", "clear" })
		mock_temp_file_manager = mock_utils.create_empty_mock_module("tungsten.util.temp_files", { "cleanup" })

		original_require = _G.require
		_G.require = function(module_path)
			if module_path == "tungsten.util.async" then
				return mock_async
			end
			if module_path == "tungsten.state" then
				return mock_state
			end
			if module_path == "tungsten.config" then
				return mock_config
			end
			if module_path == "tungsten.ui.virtual_result" then
				return mock_status_ui
			end
			if module_path == "tungsten.util.temp_files" then
				return mock_temp_file_manager
			end
			if package.loaded[module_path] then
				return package.loaded[module_path]
			end
			return original_require(module_path)
		end

		PlottingJobManager = require("tungsten.plotting.job_manager")
	end)

	after_each(function()
		_G.require = original_require
	end)

	PlottingJobManager = {
		submit = function() end,
		cancel = function() end,
		cancel_all = function() end,
		setup_autocmds = function() end,
	}

	it("should run all plot generation jobs asynchronously", function()
		-- Arrange
		local job_definition = { backend = "python", expression = "x^2" }
		local on_success_spy = spy.new()
		local on_error_spy = spy.new()

		PlottingJobManager.submit(job_definition, on_success_spy, on_error_spy)

		assert.spy(mock_async.run_job).was.called(1)
		assert.spy(mock_async.run_job).was.called_with(
			match.is_table(),
			match.is_table()
		)

		local async_opts = mock_async.run_job.calls[1].vals[2]
		async_opts.on_exit(0, "path/to/plot.png", "")

		assert.spy(on_success_spy).was.called(1)
		assert.spy(on_success_spy).was.called_with("path/to/plot.png")
		assert.spy(on_error_spy).was_not.called()
	end)

	it("should queue jobs beyond the concurrency limit and run them in FIFO order", function()
		mock_config.max_jobs = 1
		local execution_order = {}

		mock_async.run_job:callback(function(cmd, opts)
			table.insert(execution_order, cmd.id)
			vim.defer_fn(function()
				opts.on_exit(0, "done", "")
			end, 10)
		end)

		PlottingJobManager.submit({ id = "job1" })
		PlottingJobManager.submit({ id = "job2" })
		PlottingJobManager.submit({ id = "job3" })

		assert.spy(mock_async.run_job).was.called(1)
		assert.are.same({ "job1" }, execution_order)

		wait_for(function()
			return #execution_order == 3
		end, 500)

		assert.spy(mock_async.run_job).was.called(3)
		assert.are.same({ "job1", "job2", "job3" }, execution_order)
	end)

	it("should display a live progress indicator when a job starts", function()
		PlottingJobManager.submit({ expression = "sin(x)" })

		assert.spy(mock_status_ui.show).was.called(1)
		assert.spy(mock_status_ui.show).was.called_with(match.is_string(), match.is_number())
	end)

	it("should remove the indicator on job completion", function()
		mock_async.run_job:callback(function(cmd, opts)
			opts.on_exit(0, "plot.pdf", "")
		end)

		PlottingJobManager.submit({ expression = "cos(x)" })

		assert.spy(mock_status_ui.show).was.called(1)
		assert.spy(mock_status_ui.clear).was.called(1)
	end)

	it("should allow a running job to be canceled", function()
		local mock_job_handle = { cancel = spy.new() }
		mock_async.run_job:returns(mock_job_handle)
		local on_error_spy = spy.new()

		local job_id = PlottingJobManager.submit({ expression = "x^3" }, function() end, on_error_spy)

		PlottingJobManager.cancel(job_id)

		assert.spy(mock_job_handle.cancel).was.called(1)
		assert.spy(on_error_spy).was.called_with(match.table.containing({ code = "E_CANCELLED" }))
	end)

	it("should clean up temporary files if a job is canceled or fails", function()
		local mock_job_handle = { cancel = spy.new() }
		mock_async.run_job:returns(mock_job_handle)

		local job_id = PlottingJobManager.submit({ temp_file = "/tmp/plot1.tmp" })
		PlottingJobManager.cancel(job_id)
		assert.spy(mock_temp_file_manager.cleanup).was.called_with("/tmp/plot1.tmp")

		mock_async.run_job:callback(function(cmd, opts)
			opts.on_exit(1, "", "Backend crashed")
		end)
		PlottingJobManager.submit({ temp_file = "/tmp/plot2.tmp" })
		assert.spy(mock_temp_file_manager.cleanup).was.called_with("/tmp/plot2.tmp")
	end)

	it("should terminate ongoing plot jobs when Neovim exits", function()
		local cancel_all_spy = spy.on(PlottingJobManager, "cancel_all")
		local autocmd_callback

		local orig_autocmd = vim.api.nvim_create_autocmd
		vim.api.nvim_create_autocmd = spy.new(function(event, opts)
			if event == "VimLeavePre" then
				autocmd_callback = opts.callback
			end
		end)

		PlottingJobManager.setup_autocmds()
		autocmd_callback()

		assert.is_function(autocmd_callback)
		assert.spy(cancel_all_spy).was.called(1)

		vim.api.nvim_create_autocmd = orig_autocmd
		cancel_all_spy:revert()
	end)
end)
