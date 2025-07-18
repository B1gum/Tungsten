-- tests/unit/util/error_handler_spec.lua

local spy = require("luassert.spy")

describe("util.error_handler.notify_error", function()
	local error_handler
	local orig_print
	local orig_notify
	local orig_schedule

	before_each(function()
		package.loaded["tungsten.util.error_handler"] = nil
		_G.vim = _G.vim or {}
		_G.vim.log = { levels = { ERROR = 1 } }
		orig_print = _G.print
		orig_notify = _G.vim.notify
		orig_schedule = _G.vim.schedule
	end)

	after_each(function()
		_G.print = orig_print
		_G.vim.notify = orig_notify
		_G.vim.schedule = orig_schedule
	end)

	it("calls vim.notify asynchronously when available", function()
		local notify_spy = spy.new(function() end)
		local schedule_spy = spy.new(function(fn)
			fn()
		end)

		_G.vim.notify = notify_spy
		_G.vim.schedule = schedule_spy

		error_handler = require("tungsten.util.error_handler")
		error_handler.notify_error("Ctx", "Err")

		assert.spy(schedule_spy).was.called(1)
		assert.spy(notify_spy).was.called_with("Tungsten[Ctx] Err", _G.vim.log.levels.ERROR)
	end)

	it("falls back to print when vim.notify is absent", function()
		local print_spy = spy.new(function() end)
		local schedule_spy = spy.new(function(fn)
			fn()
		end)

		_G.print = print_spy
		_G.vim.notify = nil
		_G.vim.schedule = schedule_spy

		error_handler = require("tungsten.util.error_handler")
		error_handler.notify_error("X", "Y")

		assert.spy(schedule_spy).was_not.called()
		assert.spy(print_spy).was.called_with("Tungsten[X] Y")
	end)
end)
