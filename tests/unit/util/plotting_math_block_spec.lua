local vim_env = require("tests.helpers.vim_test_env")
local plotting_io = require("tungsten.util.plotting_io")

describe("plotting_io.find_math_block_end", function()
	local bufnr

	after_each(function()
		if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_delete(bufnr, { force = true })
		end
		bufnr = nil
	end)

	it("detects the closing $$ delimiter", function()
		bufnr = vim_env.setup_buffer({
			"$$",
			"f(x) = x^2",
			"$$",
			"next line",
		})

		local end_line = plotting_io.find_math_block_end(bufnr, 0)
		assert.are.equal(2, end_line)
	end)

	it("detects the closing $ delimiter", function()
		bufnr = vim_env.setup_buffer({
			"$f(x) = x^2$",
			"next line",
		})

		local end_line = plotting_io.find_math_block_end(bufnr, 0)
		assert.are.equal(0, end_line)
	end)

	it("detects the closing \\] delimiter", function()
		bufnr = vim_env.setup_buffer({
			"\\[",
			"f(x) = x^2",
			"\\]",
			"next line",
		})

		local end_line = plotting_io.find_math_block_end(bufnr, 0)
		assert.are.equal(2, end_line)
	end)

	it("detects the closing \\) delimiter", function()
		bufnr = vim_env.setup_buffer({
			"\\(",
			"f(x) = x^2",
			"\\)",
			"next line",
		})

		local end_line = plotting_io.find_math_block_end(bufnr, 0)
		assert.are.equal(2, end_line)
	end)

	it("returns nil when no closing delimiter is found", function()
		bufnr = vim_env.setup_buffer({
			"$$",
			"f(x) = x^2",
			"still inside display math",
		})

		local end_line = plotting_io.find_math_block_end(bufnr, 0)
		assert.is_nil(end_line)
	end)
end)
