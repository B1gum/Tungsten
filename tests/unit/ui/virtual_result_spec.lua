local spy = require("luassert.spy")
local match = require("luassert.match")
local mock_utils = require("tests.helpers.mock_utils")
local vim_test_env = require("tests.helpers.vim_test_env")

local api = vim.api

describe("tungsten.ui.virtual_result", function()
	local virtual_result
	local orig = {}
	before_each(function()
		orig.set_extmark = api.nvim_buf_set_extmark
		orig.del_extmark = api.nvim_buf_del_extmark

		api.nvim_buf_set_extmark = spy.new(function()
			return 1
		end)
		api.nvim_buf_del_extmark = spy.new(function() end)

		mock_utils.reset_modules({ "tungsten.ui.virtual_result" })
		virtual_result = require("tungsten.ui.virtual_result")
	end)

	after_each(function()
		api.nvim_buf_set_extmark = orig.set_extmark
		api.nvim_buf_del_extmark = orig.del_extmark
		vim_test_env.cleanup()
	end)

	it("creates virtual text extmarks", function()
		virtual_result.show("answer", 0)
		local state = require("tungsten.state")
		assert.spy(api.nvim_buf_set_extmark).was.called_with(match.is_number(), state.ns, 0, -1, match.is_table())
		local args = api.nvim_buf_set_extmark.calls[1].vals[5]
		assert.are.same({ virt_text = { { "answer" } }, virt_text_pos = "eol" }, args)
	end)

	it("clears previous extmarks on subsequent calls", function()
		api.nvim_buf_set_extmark = spy.new(function()
			return 3
		end)
		mock_utils.reset_modules({ "tungsten.ui.virtual_result" })
		virtual_result = require("tungsten.ui.virtual_result")

		virtual_result.show("one", 0)

		api.nvim_buf_set_extmark = spy.new(function()
			return 4
		end)
		virtual_result.show("two", 0)
		local state = require("tungsten.state")
		assert.spy(api.nvim_buf_del_extmark).was.called_with(match.is_number(), state.ns, 3)
	end)
end)
