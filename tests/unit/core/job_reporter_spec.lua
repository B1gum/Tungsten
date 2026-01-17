local match = require("luassert.match")
local spy = require("luassert.spy")
local vim_test_env = require("tests.helpers.vim_test_env")
local mock_utils = require("tests.helpers.mock_utils")

describe("tungsten.core.job_reporter", function()
	local job_reporter
	local mock_engine
	local mock_logger
	local logger_notify_spy
	local active_jobs
	local original_require

	local modules_to_clear_from_cache = {
		"tungsten.core.job_reporter",
		"tungsten.core.engine",
		"tungsten.util.logger",
	}

	before_each(function()
		vim_test_env.setup_buffer({ "line1" })
		active_jobs = {}
		mock_engine = {
			get_active_jobs = function()
				return active_jobs
			end,
		}
		mock_logger = {
			levels = { INFO = 3 },
			notify = function() end,
		}
		mock_logger.info = function(title, message)
			mock_logger.notify(message, mock_logger.levels.INFO, { title = title })
		end

		logger_notify_spy = spy.new(function() end)
		mock_logger.notify = logger_notify_spy

		original_require = _G.require
		_G.require = function(module_path)
			if module_path == "tungsten.core.engine" then
				return mock_engine
			end
			if module_path == "tungsten.util.logger" then
				return mock_logger
			end
			return original_require(module_path)
		end

		mock_utils.reset_modules(modules_to_clear_from_cache, original_require)
		job_reporter = require("tungsten.core.job_reporter")
	end)

	after_each(function()
		_G.require = original_require
	end)

	it("get_active_jobs_summary reports no active jobs when empty", function()
		local summary = job_reporter.get_active_jobs_summary()
		assert.are.equal("Tungsten: No active jobs.", summary)
	end)

	it("get_active_jobs_summary includes details for active jobs", function()
		active_jobs = {
			[123] = { bufnr = 1, cache_key = "key1", start_time = vim.loop.now() - 1000 },
			[456] = { bufnr = 2, cache_key = "key2", start_time = vim.loop.now() - 2000 },
		}
		local summary = job_reporter.get_active_jobs_summary()
		assert.truthy(summary:find("Active Tungsten Jobs:"))
		assert.truthy(summary:find("ID: 123"))
		assert.truthy(summary:find("ID: 456"))
	end)

	it("view_active_jobs logs the summary", function()
		active_jobs = {}
		job_reporter.view_active_jobs()
		assert
			.spy(logger_notify_spy).was
			.called_with("Tungsten: No active jobs.", mock_logger.levels.INFO, match.is_table())
	end)
end)
