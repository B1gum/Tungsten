local spy = require("luassert.spy")
local mock_utils = require("tests.helpers.mock_utils")
local vim_test_env = require("tests.helpers.vim_test_env")

local api = vim.api

describe("tungsten.ui.float_result", function()
	local float_result
	local orig = {}
	before_each(function()
		orig.create_buf = api.nvim_create_buf
		orig.set_lines = api.nvim_buf_set_lines
		orig.set_option = api.nvim_buf_set_option
		orig.open_win = api.nvim_open_win
		orig.win_close = api.nvim_win_close
		orig.win_is_valid = api.nvim_win_is_valid
		orig.keymap_set = vim.keymap.set

		api.nvim_create_buf = spy.new(function()
			return 1
		end)
		api.nvim_buf_set_lines = spy.new(function() end)
		api.nvim_buf_set_option = spy.new(function() end)
		local win_id = 10
		api.nvim_open_win = spy.new(function()
			local id = win_id
			win_id = win_id + 1
			return id
		end)
		api.nvim_win_close = spy.new(function() end)
		api.nvim_win_is_valid = spy.new(function()
			return true
		end)
		vim.keymap.set = spy.new(function() end)

		mock_utils.reset_modules({ "tungsten.ui.float_result" })
		float_result = require("tungsten.ui.float_result")
	end)

	after_each(function()
		api.nvim_create_buf = orig.create_buf
		api.nvim_buf_set_lines = orig.set_lines
		api.nvim_buf_set_option = orig.set_option
		api.nvim_open_win = orig.open_win
		api.nvim_win_close = orig.win_close
		api.nvim_win_is_valid = orig.win_is_valid
		vim.keymap.set = orig.keymap_set
		vim_test_env.cleanup()
	end)

	it("closes previous window before creating a new one", function()
		float_result.show("first")
		float_result.show("second")
		assert.spy(api.nvim_win_close).was.called_with(10, true)
		assert.spy(api.nvim_open_win).was.called(2)
	end)

	it("maps <Esc> to close the floating window", function()
		float_result.show("answer")
		local args = vim.keymap.set.calls[1].vals
		assert.are.same("n", args[1])
		assert.are.same("<Esc>", args[2])
		assert.are.equal(float_result.close, args[3])
		assert.are.equal("table", type(args[4]))
	end)
end)
