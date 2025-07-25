local vim_test_env = require("tests.helpers.vim_test_env")
local selection = require("tungsten.util.selection")
local state = require("tungsten.state")

describe("selection.create_selection_extmarks", function()
	it("creates extmarks covering the selection", function()
		local bufnr = vim_test_env.setup_buffer({ "abcdef" })
		vim_test_env.set_visual_selection(1, 2, 1, 4)
		local rbuf, s_id, e_id, mode = selection.create_selection_extmarks()
		assert.are.equal(bufnr, rbuf)
		local s = vim.api.nvim_buf_get_extmark_by_id(bufnr, state.ns, s_id, {})
		local e = vim.api.nvim_buf_get_extmark_by_id(bufnr, state.ns, e_id, {})
		assert.are.same({ 0, 1 }, s)
		assert.are.same({ 0, 4 }, e)
		assert.is_truthy(mode)
		vim_test_env.cleanup(bufnr)
	end)
end)
