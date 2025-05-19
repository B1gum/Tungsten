-- tests/unit/util/selection_spec.lua
-- Unit tests for the selection utility module.
---------------------------------------------------------------------

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local spy = require('luassert.spy')
local mock_utils = require('tests.helpers.mock_utils')

describe("tungsten.util.selection", function()
  local selection_module

  local original_vim_fn_getpos
  local original_vim_api_nvim_buf_get_lines

  local modules_to_reset = {
    'tungsten.util.selection',
  }

  before_each(function()
    _G.vim = _G.vim or {}
    _G.vim.fn = _G.vim.fn or {}
    _G.vim.api = _G.vim.api or {}

    original_vim_fn_getpos = _G.vim.fn.getpos
    original_vim_api_nvim_buf_get_lines = _G.vim.api.nvim_buf_get_lines

    _G.vim.fn.getpos = spy.new(function(marker)
      if marker == "'<" then return { 0, 1, 1, 0 } end
      if marker == "'>" then return { 0, 1, 1, 0 } end
      return { 0, 0, 0, 0 }
    end)
    _G.vim.api.nvim_buf_get_lines = spy.new(function(bufnr, start_line, end_line, strict_indexing)
      return {}
    end)

    mock_utils.reset_modules(modules_to_reset)
    selection_module = require("tungsten.util.selection")
  end)

  after_each(function()
    _G.vim.fn.getpos = original_vim_fn_getpos
    _G.vim.api.nvim_buf_get_lines = original_vim_api_nvim_buf_get_lines

    mock_utils.reset_modules(modules_to_reset)
  end)

  describe("get_visual_selection()", function()
    describe("Single-Line Selections", function()
      it("should return the correct substring for a middle selection", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 7, 0 } end
          if marker == "'>" then return { 0, 1, 11, 0 } end
        end)
        _G.vim.api.nvim_buf_get_lines = spy.new(function()
          return { "Hello World!" }
        end)
        assert.are.equal("World", selection_module.get_visual_selection())
      end)

      it("should return the correct substring for a selection at the start of the line", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 1, 0 } end
          if marker == "'>" then return { 0, 1, 5, 0 } end
        end)
        _G.vim.api.nvim_buf_get_lines = spy.new(function()
          return { "Hello World!" }
        end)
        assert.are.equal("Hello", selection_module.get_visual_selection())
      end)

      it("should return the correct substring for a selection at the end of the line", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 7, 0 } end
          if marker == "'>" then return { 0, 1, 12, 0 } end
        end)
        _G.vim.api.nvim_buf_get_lines = spy.new(function()
          return { "Hello World!" }
        end)
        assert.are.equal("World!", selection_module.get_visual_selection())
      end)

      it("should return the full line if the entire single line is selected", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 1, 0 } end
          if marker == "'>" then return { 0, 1, 12, 0 } end
        end)
        _G.vim.api.nvim_buf_get_lines = spy.new(function()
          return { "Hello World!" }
        end)
        assert.are.equal("Hello World!", selection_module.get_visual_selection())
      end)
    end)

    describe("Multi-Line Selections", function()
      it("should return correctly concatenated string for a basic multi-line selection", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 7, 0 } end
          if marker == "'>" then return { 0, 2, 5, 0 } end
        end)
        _G.vim.api.nvim_buf_get_lines = spy.new(function(b, start_idx, end_idx_api)
          assert.are.equal(0, start_idx)
          assert.are.equal(2, end_idx_api)
          return { "Hello World!", "Hi There Friend" }
        end)
        assert.are.equal("World!\nHi Th", selection_module.get_visual_selection())
      end)

      it("should correctly trim the first line from start_col", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 3, 0 } end --
          if marker == "'>" then return { 0, 2, 7, 0 } end --
        end)
        _G.vim.api.nvim_buf_get_lines = spy.new(function()
          return { "Hello", "Second Line!" }
        end)
        assert.are.equal("llo\nSecond ", selection_module.get_visual_selection())
      end)

      it("should correctly trim the last line up to end_col", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 1, 0 } end
          if marker == "'>" then return { 0, 2, 4, 0 } end
        end)
        _G.vim.api.nvim_buf_get_lines = spy.new(function()
          return { "First Line", "Second" }
        end)
        assert.are.equal("First Line\nSeco", selection_module.get_visual_selection())
      end)

      it("should handle full line selections across multiple lines", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 1, 0 } end
          if marker == "'>" then return { 0, 2, 7, 0 } end
        end)
        _G.vim.api.nvim_buf_get_lines = spy.new(function()
          return { "Line 1", "Line 2!" }
        end)
        assert.are.equal("Line 1\nLine 2!", selection_module.get_visual_selection())
      end)

      it("should include an empty line if it's part of the multi-line selection", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 1, 0 } end
          if marker == "'>" then return { 0, 3, 4, 0 } end
        end)
        _G.vim.api.nvim_buf_get_lines = spy.new(function()
          return { "Start", "", "End Line" }
        end)
        assert.are.equal("Start\n\nEnd ", selection_module.get_visual_selection())
      end)
    end)

    describe("Edge Cases and Empty Selections", function()
      it("should return an empty string if nvim_buf_get_lines returns an empty table", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 1, 0 } end
          if marker == "'>" then return { 0, 1, 5, 0 } end
        end)
        _G.vim.api.nvim_buf_get_lines = spy.new(function()
          return {}
        end)
        assert.are.equal("", selection_module.get_visual_selection())
      end)

      it("should return an empty string if a single empty line is selected", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 1, 0 } end
          if marker == "'>" then return { 0, 1, 0, 0 } end
        end)
        _G.vim.api.nvim_buf_get_lines = spy.new(function()
          return { "" }
        end)
        assert.are.equal("", selection_module.get_visual_selection())

        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 1, 0 } end
          if marker == "'>" then return { 0, 1, 1, 0 } end
        end)
         _G.vim.api.nvim_buf_get_lines = spy.new(function()
          return { "" }
        end)
        assert.are.equal("", selection_module.get_visual_selection())
      end)

      it("should handle selection starting and ending on the same non-existent column of an empty line", function()
        _G.vim.fn.getpos = spy.new(function(marker)
            if marker == "'<" then return { 0, 1, 1, 0 } end
            if marker == "'>" then return { 0, 1, 0, 0 } end
        end)
        _G.vim.api.nvim_buf_get_lines = spy.new(function()
            return { "" }
        end)
        assert.are.equal("", selection_module.get_visual_selection())
      end)
    end)
  end)
end)
