-- tests/unit/util/selection_spec.lua
-- Unit tests for the selection utility module.
---------------------------------------------------------------------

-- Ensure package path allows requiring project modules
package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local spy = require('luassert.spy')
local mock_utils = require('tests.helpers.mock_utils') -- Assuming you have mock_utils

describe("tungsten.util.selection", function()
  local selection_module

  -- Store original Neovim API functions to restore them after tests
  local original_vim_fn_getpos
  local original_vim_api_nvim_buf_get_lines

  local modules_to_reset = {
    'tungsten.util.selection',
  }

  before_each(function()
    -- Mock Neovim's global vim table and its relevant functions
    _G.vim = _G.vim or {}
    _G.vim.fn = _G.vim.fn or {}
    _G.vim.api = _G.vim.api or {}

    original_vim_fn_getpos = _G.vim.fn.getpos
    original_vim_api_nvim_buf_get_lines = _G.vim.api.nvim_buf_get_lines

    -- Default mock implementations (can be overridden in specific tests)
    _G.vim.fn.getpos = spy.new(function(marker)
      if marker == "'<" then return { 0, 1, 1, 0 } end -- {bufnr, lnum, col, off}
      if marker == "'>" then return { 0, 1, 1, 0 } end
      return { 0, 0, 0, 0 } -- Should not happen in normal flow
    end)
    _G.vim.api.nvim_buf_get_lines = spy.new(function(bufnr, start_line, end_line, strict_indexing)
      return {} -- Default to returning no lines
    end)

    -- Reset the specific module we are testing to ensure a clean state
    mock_utils.reset_modules(modules_to_reset)
    selection_module = require("tungsten.util.selection")
  end)

  after_each(function()
    -- Restore original Neovim API functions
    _G.vim.fn.getpos = original_vim_fn_getpos
    _G.vim.api.nvim_buf_get_lines = original_vim_api_nvim_buf_get_lines

    -- Clean up any global mocks if necessary, though spies handle this mostly
    mock_utils.reset_modules(modules_to_reset)
  end)

  describe("get_visual_selection()", function()
    describe("Single-Line Selections", function()
      it("should return the correct substring for a middle selection", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          -- For "Hello World!"
          -- To get "World": 'W' is col 7, 'd' is col 11
          if marker == "'<" then return { 0, 1, 7, 0 } end -- Line 1, Col 7
          if marker == "'>" then return { 0, 1, 11, 0 } end -- Line 1, Col 11
        end)
        _G.vim.api.nvim_buf_get_lines = spy.new(function()
          return { "Hello World!" }
        end)
        assert.are.equal("World", selection_module.get_visual_selection())
      end)

      it("should return the correct substring for a selection at the start of the line", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 1, 0 } end -- Line 1, Col 1
          if marker == "'>" then return { 0, 1, 5, 0 } end -- Line 1, Col 5
        end)
        _G.vim.api.nvim_buf_get_lines = spy.new(function()
          return { "Hello World!" }
        end)
        assert.are.equal("Hello", selection_module.get_visual_selection())
      end)

      it("should return the correct substring for a selection at the end of the line", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 7, 0 } end -- Line 1, Col 7 ("World!")
          if marker == "'>" then return { 0, 1, 12, 0 } end -- Line 1, Col 12 (end of "Hello World!")
        end)
        _G.vim.api.nvim_buf_get_lines = spy.new(function()
          return { "Hello World!" }
        end)
        assert.are.equal("World!", selection_module.get_visual_selection())
      end)

      it("should return the full line if the entire single line is selected", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 1, 0 } end
          if marker == "'>" then return { 0, 1, 12, 0 } end -- Length of "Hello World!" is 12
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
          if marker == "'<" then return { 0, 1, 7, 0 } end -- Start: Line 1, Col 7 ("World!")
          if marker == "'>" then return { 0, 2, 5, 0 } end -- End: Line 2, Col 5 ("There") from "Hi There Friend"
        end)
        _G.vim.api.nvim_buf_get_lines = spy.new(function(b, start_idx, end_idx_api)
          -- nvim_buf_get_lines uses 0-indexed start_line and exclusive end_line
          assert.are.equal(0, start_idx) -- (1 - 1)
          assert.are.equal(2, end_idx_api) -- (end_line)
          return { "Hello World!", "Hi There Friend" }
        end)
        assert.are.equal("World!\nHi Th", selection_module.get_visual_selection())
      end)

      it("should correctly trim the first line from start_col", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 3, 0 } end -- "llo" from "Hello"
          if marker == "'>" then return { 0, 2, 7, 0 } end -- "Second " from "Second Line!" (length 12, col 7 is space)
        end)
        _G.vim.api.nvim_buf_get_lines = spy.new(function()
          return { "Hello", "Second Line!" }
        end)
        assert.are.equal("llo\nSecond ", selection_module.get_visual_selection())
      end)

      it("should correctly trim the last line up to end_col", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 1, 0 } end -- "First Line"
          if marker == "'>" then return { 0, 2, 4, 0 } end -- "Seco" from "Second"
        end)
        _G.vim.api.nvim_buf_get_lines = spy.new(function()
          return { "First Line", "Second" }
        end)
        assert.are.equal("First Line\nSeco", selection_module.get_visual_selection())
      end)

      it("should handle full line selections across multiple lines", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 1, 0 } end
          if marker == "'>" then return { 0, 2, 7, 0 } end -- Assuming "Line 2!" is 7 chars
        end)
        _G.vim.api.nvim_buf_get_lines = spy.new(function()
          return { "Line 1", "Line 2!" }
        end)
        assert.are.equal("Line 1\nLine 2!", selection_module.get_visual_selection())
      end)

      it("should include an empty line if it's part of the multi-line selection", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 1, 0 } end -- "Start"
          if marker == "'>" then return { 0, 3, 4, 0 } end -- "End " from "End Line"
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
          if marker == "'>" then return { 0, 1, 0, 0 } end -- Visual selection of empty line often gives end_col 0
        end)
        _G.vim.api.nvim_buf_get_lines = spy.new(function()
          return { "" }
        end)
        assert.are.equal("", selection_module.get_visual_selection())

        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 1, 0 } end
          if marker == "'>" then return { 0, 1, 1, 0 } end -- Or end_col 1 if cursor stays on line
        end)
         _G.vim.api.nvim_buf_get_lines = spy.new(function()
          return { "" }
        end)
        -- string.sub("", 1, 1) might be an issue if the line is truly empty.
        -- However, Neovim typically gives col 1 for start and end of an empty line if it's selected.
        -- string.sub("", 1, 1) is "", string.sub("", 1, 0) is ""
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
