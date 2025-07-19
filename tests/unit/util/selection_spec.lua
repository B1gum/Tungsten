-- tests/unit/util/selection_spec.lua
-- Unit tests for the selection utility module.

local spy = require("luassert.spy")
local vim_test_env = require("tests.helpers.vim_test_env")
local mock_utils = require("tests.helpers.mock_utils")

describe("tungsten.util.selection", function()
	local selection_module

	local original_vim_fn_getpos
	local original_vim_api_nvim_buf_get_text

	local modules_to_clear_from_cache = {
		"tungsten.util.selection",
	}

	before_each(function()
		_G.vim = _G.vim or {}
		_G.vim.fn = _G.vim.fn or {}
		_G.vim.api = _G.vim.api or {}

		original_vim_fn_getpos = _G.vim.fn.getpos
		original_vim_api_nvim_buf_get_text = _G.vim.api.nvim_buf_get_text

		_G.vim.fn.getpos = spy.new(function(marker)
			if marker == "'<" then
				return { 0, 1, 1, 0 }
			end
			if marker == "'>" then
				return { 0, 1, 1, 0 }
			end
			return { 0, 0, 0, 0 }
		end)

		_G.vim.api.nvim_buf_get_text = spy.new(function(bufnr, start_line, start_col, end_line, end_col, opts)
			return {}
		end)

		mock_utils.reset_modules(modules_to_clear_from_cache)
		selection_module = require("tungsten.util.selection")
	end)

	after_each(function()
		if _G.vim.fn.getpos and type(_G.vim.fn.getpos) == "table" and _G.vim.fn.getpos.clear then
			_G.vim.fn.getpos:clear()
		end
		if
			_G.vim.api.nvim_buf_get_text
			and type(_G.vim.api.nvim_buf_get_text) == "table"
			and _G.vim.api.nvim_buf_get_text.clear
		then
			_G.vim.api.nvim_buf_get_text:clear()
		end

		_G.vim.fn.getpos = original_vim_fn_getpos
		_G.vim.api.nvim_buf_get_text = original_vim_api_nvim_buf_get_text

		mock_utils.reset_modules(modules_to_clear_from_cache)

		if vim_test_env and vim_test_env.teardown then
			vim_test_env.teardown()
		elseif vim_test_env and vim_test_env.cleanup then
			vim_test_env.cleanup()
		end
	end)

	describe("get_visual_selection()", function()
		describe("Single-Line Selections", function()
			it("should return the correct substring for a middle selection", function()
				_G.vim.fn.getpos = spy.new(function(marker)
					if marker == "'<" then
						return { 0, 1, 7, 0 }
					end
					if marker == "'>" then
						return { 0, 1, 11, 0 }
					end
					return { 0, 0, 0, 0 }
				end)
				_G.vim.api.nvim_buf_get_text = spy.new(function(bufnr, s_line, s_col, e_line, e_col, opts)
					if bufnr == 0 and s_line == 0 and s_col == 6 and e_line == 0 and e_col == 11 then
						return { "World" }
					end
					return {}
				end)
				assert.are.equal("World", selection_module.get_visual_selection())
			end)

			it("should return the correct substring for a selection at the start of the line", function()
				_G.vim.fn.getpos = spy.new(function(marker)
					if marker == "'<" then
						return { 0, 1, 1, 0 }
					end
					if marker == "'>" then
						return { 0, 1, 5, 0 }
					end
					return { 0, 0, 0, 0 }
				end)
				_G.vim.api.nvim_buf_get_text = spy.new(function(b, sl, sc, el, ec, o)
					if sl == 0 and sc == 0 and el == 0 and ec == 5 then
						return { "Hello" }
					end
					return {}
				end)
				assert.are.equal("Hello", selection_module.get_visual_selection())
			end)

			it("should return the correct substring for a selection at the end of the line", function()
				_G.vim.fn.getpos = spy.new(function(marker)
					if marker == "'<" then
						return { 0, 1, 7, 0 }
					end
					if marker == "'>" then
						return { 0, 1, 12, 0 }
					end
					return { 0, 0, 0, 0 }
				end)
				_G.vim.api.nvim_buf_get_text = spy.new(function(b, sl, sc, el, ec, o)
					if sl == 0 and sc == 6 and el == 0 and ec == 12 then
						return { "World!" }
					end
					return {}
				end)
				assert.are.equal("World!", selection_module.get_visual_selection())
			end)

			it("should return the full line if the entire single line is selected", function()
				_G.vim.fn.getpos = spy.new(function(marker)
					if marker == "'<" then
						return { 0, 1, 1, 0 }
					end
					if marker == "'>" then
						return { 0, 1, 12, 0 }
					end
					return { 0, 0, 0, 0 }
				end)
				_G.vim.api.nvim_buf_get_text = spy.new(function(b, sl, sc, el, ec, o)
					if sl == 0 and sc == 0 and el == 0 and ec == 12 then
						return { "Hello World!" }
					end
					return {}
				end)
				assert.are.equal("Hello World!", selection_module.get_visual_selection())
			end)
		end)

		describe("Multi-Line Selections", function()
			it("should return correctly concatenated string for a basic multi-line selection", function()
				_G.vim.fn.getpos = spy.new(function(marker)
					if marker == "'<" then
						return { 0, 1, 7, 0 }
					end
					if marker == "'>" then
						return { 0, 2, 5, 0 }
					end
					return { 0, 0, 0, 0 }
				end)
				_G.vim.api.nvim_buf_get_text = spy.new(function(b, sl, sc, el, ec, o)
					if sl == 0 and sc == 6 and el == 1 and ec == 5 then
						return { "World!", "Hi Th" }
					end
					return {}
				end)
				assert.are.equal("World!\nHi Th", selection_module.get_visual_selection())
			end)

			it("should correctly trim the first line from start_col", function()
				_G.vim.fn.getpos = spy.new(function(marker)
					if marker == "'<" then
						return { 0, 1, 3, 0 }
					end
					if marker == "'>" then
						return { 0, 2, 7, 0 }
					end
					return { 0, 0, 0, 0 }
				end)
				_G.vim.api.nvim_buf_get_text = spy.new(function(b, sl, sc, el, ec, o)
					if sl == 0 and sc == 2 and el == 1 and ec == 7 then
						return { "llo", "Second " }
					end
					return {}
				end)
				assert.are.equal("llo\nSecond ", selection_module.get_visual_selection())
			end)

			it("should correctly trim the last line up to end_col", function()
				_G.vim.fn.getpos = spy.new(function(marker)
					if marker == "'<" then
						return { 0, 1, 1, 0 }
					end
					if marker == "'>" then
						return { 0, 2, 4, 0 }
					end
					return { 0, 0, 0, 0 }
				end)
				_G.vim.api.nvim_buf_get_text = spy.new(function(b, sl, sc, el, ec, o)
					if sl == 0 and sc == 0 and el == 1 and ec == 4 then
						return { "First Line", "Seco" }
					end
					return {}
				end)
				assert.are.equal("First Line\nSeco", selection_module.get_visual_selection())
			end)

			it("should handle full line selections across multiple lines", function()
				_G.vim.fn.getpos = spy.new(function(marker)
					if marker == "'<" then
						return { 0, 1, 1, 0 }
					end
					if marker == "'>" then
						return { 0, 2, 7, 0 }
					end
					return { 0, 0, 0, 0 }
				end)
				_G.vim.api.nvim_buf_get_text = spy.new(function(b, sl, sc, el, ec, o)
					if sl == 0 and sc == 0 and el == 1 and ec == 7 then
						return { "Line 1", "Line 2!" }
					end
					return {}
				end)
				assert.are.equal("Line 1\nLine 2!", selection_module.get_visual_selection())
			end)

			it("should include an empty line if it's part of the multi-line selection", function()
				_G.vim.fn.getpos = spy.new(function(marker)
					if marker == "'<" then
						return { 0, 1, 1, 0 }
					end
					if marker == "'>" then
						return { 0, 3, 4, 0 }
					end
					return { 0, 0, 0, 0 }
				end)
				_G.vim.api.nvim_buf_get_text = spy.new(function(b, sl, sc, el, ec, o)
					if sl == 0 and sc == 0 and el == 2 and ec == 4 then
						return { "Start", "", "End " }
					end
					return {}
				end)
				assert.are.equal("Start\n\nEnd ", selection_module.get_visual_selection())
			end)
		end)

		describe("Edge Cases and Empty Selections", function()
			it("should return an empty string if nvim_buf_get_text returns an empty table (e.g. invalid range)", function()
				_G.vim.fn.getpos = spy.new(function(marker)
					if marker == "'<" then
						return { 0, 1, 1, 0 }
					end
					if marker == "'>" then
						return { 0, 1, 5, 0 }
					end
					return { 0, 0, 0, 0 }
				end)
				_G.vim.api.nvim_buf_get_text = spy.new(function()
					return {}
				end)
				assert.are.equal("", selection_module.get_visual_selection())
			end)

			it("should return an empty string if a single empty line is selected", function()
				_G.vim.fn.getpos = spy.new(function(marker)
					if marker == "'<" then
						return { 0, 1, 1, 0 }
					end
					if marker == "'>" then
						return { 0, 1, 1, 0 }
					end
					return { 0, 0, 0, 0 }
				end)
				_G.vim.api.nvim_buf_get_text = spy.new(function(b, sl, sc, el, ec, o)
					if sl == 0 and sc == 0 and el == 0 and ec == 0 then
						return { "" }
					end
					return {}
				end)
				assert.are.equal("", selection_module.get_visual_selection())
			end)

			it("should handle selection where start_col > end_col (e.g. cursor moved left)", function()
				_G.vim.fn.getpos = spy.new(function(marker)
					if marker == "'<" then
						return { 0, 1, 5, 0 }
					end
					if marker == "'>" then
						return { 0, 1, 1, 0 }
					end
					return { 0, 0, 0, 0 }
				end)
				_G.vim.api.nvim_buf_get_text = spy.new(function(b, sl, sc, el, ec, o)
					return {}
				end)
				assert.are.equal("", selection_module.get_visual_selection())
			end)

      it("should handle reversed line selection", function()
        _G.vim.fn.getpos = spy.new(function(marker)
            if marker == "'<" then return { 0, 3, 1, 0 } end
            if marker == "'>" then return { 0, 1, 5, 0 } end
            return {0,0,0,0}
        end)
        _G.vim.api.nvim_buf_get_text = spy.new(function()
            return {}
        end)
        assert.are.equal("", selection_module.get_visual_selection())
      end)

      it("should return an empty string when marks are unset", function()
        _G.vim.fn.getpos = spy.new(function()
            return {0,0,0,0}
        end)
        _G.vim.api.nvim_buf_get_text = spy.new(function()
            return {}
        end)
        assert.are.equal("", selection_module.get_visual_selection())
      end)
		end)
	end)
end)
