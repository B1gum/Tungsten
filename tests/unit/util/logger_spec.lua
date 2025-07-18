-- tests/unit/util/logger_spec.lua

local logger_module
local vim_notify_spy
local original_print
local spy = require("luassert.spy")
local mock_utils = require("tests.helpers.mock_utils")

describe("util.logger", function()
	before_each(function()
		mock_utils.reset_modules({ "tungsten.util.logger" })
		vim_notify_spy = spy.new(function() end)
		_G.vim = _G.vim or {}
		_G.vim.notify = vim_notify_spy
		_G.vim.schedule = function(fn)
			fn()
		end
		_G.vim.log = { levels = { DEBUG = 1, INFO = 2, WARN = 3, ERROR = 4 } }
		original_print = _G.print
		logger_module = require("tungsten.util.logger")
		logger_module.set_level("DEBUG")
	end)

	after_each(function()
		_G.print = original_print
	end)

	it("info() calls vim.notify with INFO level", function()
		logger_module.info("Test", "message")
		assert.spy(vim_notify_spy).was.called_with("message", logger_module.levels.INFO, { title = "Test" })
	end)

	it("defaults title to Tungsten", function()
		logger_module.info("hello")
		assert.spy(vim_notify_spy).was.called_with("hello", logger_module.levels.INFO, { title = "Tungsten" })
	end)

	it("respects log level settings", function()
		logger_module.set_level("INFO")
		logger_module.debug("t", "m")
		assert.spy(vim_notify_spy).was_not.called()
	end)

	it("falls back to print when vim.notify is unavailable", function()
		local print_spy = spy.new(function() end)
		_G.print = print_spy
		_G.vim.notify = nil
		logger_module.info("Test", "fallback")
		assert.spy(print_spy).was.called_with("[Test] [INFO] fallback")
	end)

	it("suppresses messages below the configured log level", function()
		local print_spy = spy.new(function() end)
		_G.print = print_spy
		_G.vim.notify = nil
		logger_module.set_level("ERROR")
		logger_module.warn("Test", "warn")
		logger_module.error("Test", "error")
		assert.spy(print_spy).was.called(1)
		assert.spy(print_spy).was.called_with("[Test] [ERROR] error")
	end)
end)
