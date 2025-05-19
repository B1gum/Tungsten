-- tests/unit/util/insert_result_spec.lua
-- Unit tests for the insert_result utility function.
---------------------------------------------------------------------

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local spy = require('luassert.spy')
local mock_utils = require('tests.helpers.mock_utils')

describe("tungsten.util.insert_result", function()
  local insert_result

  local original_vim_fn_line, original_vim_fn_col, original_vim_fn_getline
  local original_vim_fn_setline, original_vim_fn_split
  local original_vim_api_nvim_buf_set_lines

  local modules_to_reset = {
    'tungsten.util.insert_result',
  }

  before_each(function()
    _G.vim = _G.vim or {}
    _G.vim.fn = _G.vim.fn or {}
    _G.vim.api = _G.vim.api or {}

    original_vim_fn_line = _G.vim.fn.line
    original_vim_fn_col = _G.vim.fn.col
    original_vim_fn_getline = _G.vim.fn.getline
    original_vim_fn_setline = _G.vim.fn.setline
    original_vim_fn_split = _G.vim.fn.split
    original_vim_api_nvim_buf_set_lines = _G.vim.api.nvim_buf_set_lines

    _G.vim.fn.line = function() return 0 end
    _G.vim.fn.col = function() return 0 end
    _G.vim.fn.getline = function() return {} end
    _G.vim.fn.setline = function() end
    _G.vim.fn.split = function(str, sep)
      sep = sep or "\n"
      local result = {}
      if str == nil then return result end
      if #str == 0 then table.insert(result, ""); return result end
      local current_segment = ""
      for i = 1, #str do
        local char = str:sub(i, i)
        if char == sep then
          table.insert(result, current_segment)
          current_segment = ""
        else
          current_segment = current_segment .. char
        end
      end
      table.insert(result, current_segment)
      return result
    end
    _G.vim.api.nvim_buf_set_lines = function() end

    mock_utils.reset_modules(modules_to_reset)
    insert_result = require("tungsten.util.insert_result")
  end)

  after_each(function()
    _G.vim.fn.line = original_vim_fn_line
    _G.vim.fn.col = original_vim_fn_col
    _G.vim.fn.getline = original_vim_fn_getline
    _G.vim.fn.setline = original_vim_fn_setline
    _G.vim.fn.split = original_vim_fn_split
    _G.vim.api.nvim_buf_set_lines = original_vim_api_nvim_buf_set_lines

    mock_utils.reset_modules(modules_to_reset)
  end)

  describe("insert_result(result_text)", function()
    describe("Single-Line Selection", function()
      it("should append ' = result_text' and call vim.fn.setline for a selection at the middle of the line", function()
        _G.vim.fn.line = spy.new(function(marker)
          if marker == "'<" or marker == "'>" then return 5 end; return 0
        end)
        _G.vim.fn.col = spy.new(function(marker)
          if marker == "'<" then return 7 end; if marker == "'>" then return 12 end; return 0
        end)
        _G.vim.fn.getline = spy.new(function(start_row, end_row)
          assert.are.equal(5, start_row); assert.are.equal(5, end_row); return { "This is a test line." }
        end)
        _G.vim.fn.setline = spy.new(function() end)

        local result = "my_result"
        insert_result.insert_result(result)

        assert.spy(_G.vim.fn.setline).was.called(1)
        assert.spy(_G.vim.fn.setline).was.called_with(5, "s a te = my_result")
      end)

      it("should correctly handle selection at the beginning of the line", function()
        _G.vim.fn.line = spy.new(function() return 1 end)
        _G.vim.fn.col = spy.new(function(marker)
          if marker == "'<" then return 1 end; if marker == "'>" then return 4 end; return 0
        end)
        _G.vim.fn.getline = spy.new(function() return { "This is a test." } end)
        _G.vim.fn.setline = spy.new(function() end)

        insert_result.insert_result("res_begin")
        assert.spy(_G.vim.fn.setline).was.called_with(1, "This = res_begin")
      end)

      it("should correctly handle selection at the end of the line", function()
        _G.vim.fn.line = spy.new(function() return 1 end)
        _G.vim.fn.col = spy.new(function(marker)
          if marker == "'<" then return 12 end; if marker == "'>" then return 16 end; return 0
        end)
        _G.vim.fn.getline = spy.new(function() return { "This is a test." } end)
        _G.vim.fn.setline = spy.new(function() end)

        insert_result.insert_result("res_end")
        assert.spy(_G.vim.fn.setline).was.called_with(1, "est. = res_end")
      end)

       it("should append ' = ' when result_text is empty for single-line selection", function()
        _G.vim.fn.line = spy.new(function() return 3 end)
        _G.vim.fn.col = spy.new(function(marker)
          if marker == "'<" then return 3 end; if marker == "'>" then return 5 end; return 0
        end)
        _G.vim.fn.getline = spy.new(function() return { "a foo bar" } end)
        _G.vim.fn.setline = spy.new(function() end)

        insert_result.insert_result("")
        assert.spy(_G.vim.fn.setline).was.called_with(3, "foo = ")
      end)
    end)

    describe("Multi-Line Selection", function()
      it("should append ' = result_text' and call vim.api.nvim_buf_set_lines for a multi-line selection", function()
        _G.vim.fn.line = spy.new(function(marker)
          if marker == "'<" then return 2 end; if marker == "'>" then return 4 end; return 0
        end)
        _G.vim.fn.col = spy.new(function(marker)
          if marker == "'<" then return 3 end
          if marker == "'>" then return 7 end
          return 0
        end)
        _G.vim.fn.getline = spy.new(function(start_row, end_row)
          assert.are.equal(2, start_row); assert.are.equal(4, end_row)
          return {
            "This is the first line.",
            "This is the second line entirely selected.",
            "This is the third line, partially.",
          }
        end)
        _G.vim.api.nvim_buf_set_lines = spy.new(function() end)

        local result = "multi_res"
        insert_result.insert_result(result)

        assert.spy(_G.vim.api.nvim_buf_set_lines).was.called(1)
        local bufnr, start_row_api, end_row_api, strict_idx, replacement = unpack(_G.vim.api.nvim_buf_set_lines.calls[1].vals)
        assert.are.equal(0, bufnr)
        assert.are.equal(1, start_row_api)
        assert.are.equal(4, end_row_api)
        assert.is_false(strict_idx)
        assert.are.same({ "is is the first line.", "This is the second line entirely selected.", "This is = multi_res" }, replacement)
      end)

      it("should correctly trim the first and last lines of a multi-line selection", function()
        _G.vim.fn.line = spy.new(function(marker)
            if marker == "'<" then return 1 end; if marker == "'>" then return 2 end; return 0
        end)
        _G.vim.fn.col = spy.new(function(marker)
            if marker == "'<" then return 7 end; if marker == "'>" then return 3 end; return 0
        end)
        _G.vim.fn.getline = spy.new(function()
            return {"start select middle", "end of selection"}
        end)
        _G.vim.api.nvim_buf_set_lines = spy.new(function() end)

        insert_result.insert_result("trimmed_result")
        assert.spy(_G.vim.api.nvim_buf_set_lines).was.called(1)
        local _, _, _, _, replacement = unpack(_G.vim.api.nvim_buf_set_lines.calls[1].vals)
        assert.are.same({"select middle", "end = trimmed_result"}, replacement)
      end)

      it("should append ' = ' when result_text is empty for multi-line selection", function()
        _G.vim.fn.line = spy.new(function(marker)
          if marker == "'<" then return 10 end; if marker == "'>" then return 11 end; return 0
        end)
        _G.vim.fn.col = spy.new(function(marker)
          if marker == "'<" then return 1 end; if marker == "'>" then return 5 end; return 0
        end)
        _G.vim.fn.getline = spy.new(function() return { "Line ten", "Line eleven has more" } end)
        _G.vim.api.nvim_buf_set_lines = spy.new(function() end)

        insert_result.insert_result("")
        assert.spy(_G.vim.api.nvim_buf_set_lines).was.called(1)
        local _, _, _, _, replacement = unpack(_G.vim.api.nvim_buf_set_lines.calls[1].vals)
        assert.are.same({ "Line ten", "Line  = " }, replacement)
      end)

      it("should handle result_text containing newlines correctly in multi-line selection", function()
        _G.vim.fn.line = spy.new(function(marker)
          if marker == "'<" then return 1 end; if marker == "'>" then return 2 end; return 0
        end)
        _G.vim.fn.col = spy.new(function(marker)
          if marker == "'<" then return 1 end; if marker == "'>" then return 4 end; return 0
        end)
        _G.vim.fn.getline = spy.new(function() return { "First line", "Second line" } end)
        _G.vim.fn.split = spy.new(_G.vim.fn.split)
        _G.vim.api.nvim_buf_set_lines = spy.new(function() end)


        local result_with_newline = "result\nwith new line"
        insert_result.insert_result(result_with_newline)

        assert.spy(_G.vim.api.nvim_buf_set_lines).was.called(1)
        local _, _, _, _, replacement = unpack(_G.vim.api.nvim_buf_set_lines.calls[1].vals)
        assert.are.same({ "First line", "Seco = result", "with new line" }, replacement)
        assert.spy(_G.vim.fn.split).was.called_with("First line\nSeco = result\nwith new line", "\n")
      end)

      it("should handle result_text containing newlines correctly in single-line selection (inserted text creates new lines)", function()
        _G.vim.fn.line = spy.new(function() return 1 end)
        _G.vim.fn.col = spy.new(function(marker)
            if marker == "'<" then return 1 end; if marker == "'>" then return 6 end; return 0
        end)
        _G.vim.fn.getline = spy.new(function() return { "Select this." } end)
        _G.vim.fn.setline = spy.new(function() end)

        local result_with_newline = "new\nresult"
        insert_result.insert_result(result_with_newline)
        assert.spy(_G.vim.fn.setline).was.called_with(1, "Select = new\nresult")
      end)
    end)

    describe("Edge Cases and No-ops", function()
      it("should do nothing if vim.fn.getline returns an empty table (no lines in selection)", function()
        _G.vim.fn.line = spy.new(function() return 1 end)
        _G.vim.fn.col = spy.new(function() return 1 end)
        _G.vim.fn.getline = spy.new(function() return {} end)
        _G.vim.fn.setline = spy.new(function() end)
        _G.vim.api.nvim_buf_set_lines = spy.new(function() end)


        insert_result.insert_result("some_result")

        assert.spy(_G.vim.fn.setline).was_not.called()
        assert.spy(_G.vim.api.nvim_buf_set_lines).was_not.called()
      end)

      it("should handle selection of an empty line correctly", function()
        _G.vim.fn.line = spy.new(function() return 1 end)
        _G.vim.fn.col = spy.new(function(marker)
          if marker == "'<" then return 1 end; if marker == "'>" then return 0 end; return 0
        end)
        _G.vim.fn.getline = spy.new(function() return { "" } end)
        _G.vim.fn.setline = spy.new(function() end)

        insert_result.insert_result("res_empty_line")
        assert.spy(_G.vim.fn.setline).was.called(1)
        assert.spy(_G.vim.fn.setline).was.called_with(1, " = res_empty_line")
      end)
    end)
  end)
end)
