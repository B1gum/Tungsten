local vim_test_env = require("tests.helpers.vim_test_env")
local wait_for = require("tests.helpers.wait").wait_for

local insert_result = require("tungsten.util.insert_result")
local selection = require("tungsten.util.selection")

describe("insert_result with extmarks", function()
	it("handles asynchronous insertions with shifting text", function()
		local bufnr = vim_test_env.setup_buffer({ "expr1", "expr2" })

		vim_test_env.set_visual_selection(1, 1, 1, 6)
		local _, s1, e1, m1 = selection.create_selection_extmarks()
		local sel1 = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1]

		vim_test_env.set_visual_selection(2, 1, 2, 6)
		local _, s2, e2, m2 = selection.create_selection_extmarks()
		local sel2 = vim.api.nvim_buf_get_lines(bufnr, 1, 2, false)[1]

		local done = 0
		vim.defer_fn(function()
			insert_result.insert_result("res1\nmore", " = ", s1, e1, sel1, m1)
			done = done + 1
		end, 10)

		vim.defer_fn(function()
			insert_result.insert_result("res2", " = ", s2, e2, sel2, m2)
			done = done + 1
		end, 50)

		wait_for(function()
			return done == 2
		end, 200)

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		assert.are.same({ "expr1 = res1", "more", "expr2 = res2" }, lines)
		vim_test_env.cleanup(bufnr)
	end)
end)
