package.path = "./tests/?.lua;./tests/?/init.lua;" .. package.path
local stub = require("luassert.stub")
local mock_utils = require("tests.helpers.mock_utils")

local selection_utils

describe("plotting selection utilities", function()
	before_each(function()
		mock_utils.reset_modules({ "tungsten.util.selection", "tungsten.domains.plotting.workflow.selection" })
		selection_utils = require("tungsten.domains.plotting.workflow.selection")
	end)

	it("returns defaults when selection marks are unset", function()
		local getpos_stub = stub(vim.fn, "getpos", function()
			return { 0, 0, 0, 0 }
		end)
		local bufnr_stub = stub(vim.api, "nvim_get_current_buf", function()
			return 42
		end)
		local lines_stub = stub(vim.api, "nvim_buf_get_lines", function()
			return { "" }
		end)

		local bufnr, start_line, start_col, end_line, end_col = selection_utils.get_selection_range()

		assert.equals(42, bufnr)
		assert.are.same({ 0, 0, 0, 0 }, { start_line, start_col, end_line, end_col })

		getpos_stub:revert()
		bufnr_stub:revert()
		lines_stub:revert()
	end)

	it("normalizes inverted marks and trims the end column to the line length", function()
		local bufnr_stub = stub(vim.api, "nvim_get_current_buf", function()
			return 7
		end)
		local getpos_stub = stub(vim.fn, "getpos", function(mark)
			if mark == "'<" then
				return { 7, 2, 3, 0 }
			end
			return { 7, 1, 10, 0 }
		end)
		local lines_stub = stub(vim.api, "nvim_buf_get_lines", function(_, start, _, _)
			if start == 0 then
				return { "first line" }
			end
			return { "second" }
		end)

		local _, start_line, start_col, end_line, end_col = selection_utils.get_selection_range()

		assert.are.same(0, start_line)
		assert.are.same(9, start_col)
		assert.is_true(end_line >= start_line)
		assert.are.same(3, end_col)

		getpos_stub:revert()
		bufnr_stub:revert()
		lines_stub:revert()
	end)

	it("honors visual line mode by expanding to whole lines", function()
		local mode_stub = stub(vim.fn, "mode", function()
			return "V"
		end)
		local getpos_stub = stub(vim.fn, "getpos", function(mark)
			if mark == "'<" then
				return { 3, 1, 2, 0 }
			end
			return { 3, 2, 5, 0 }
		end)
		local lines_stub = stub(vim.api, "nvim_buf_get_lines", function()
			return { "line text" }
		end)

		local _, start_line, start_col, end_line, end_col = selection_utils.get_selection_range()

		assert.are.same({ 0, 0, 2, 0 }, { start_line, start_col, end_line, end_col })
		mode_stub:revert()
		getpos_stub:revert()
		lines_stub:revert()
	end)

	it("trims visual selections returned by util.selection", function()
		local original = require("tungsten.util.selection")
		local selection_stub = stub(original, "get_visual_selection", function()
			return "   spaced text   "
		end)

		assert.equals("spaced text", selection_utils.get_trimmed_visual_selection())

		selection_stub:revert()
	end)

	it("guards against non-string selections", function()
		local original = require("tungsten.util.selection")
		local selection_stub = stub(original, "get_visual_selection", function()
			return { "table" }
		end)

		assert.equals("", selection_utils.get_trimmed_visual_selection())

		selection_stub:revert()
	end)
end)
