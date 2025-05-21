-- tests/unit/util/insert_result_spec.lua
-- Unit tests for the insert_result utility function.
---------------------------------------------------------------------

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local spy = require 'luassert.spy'
local mock_utils = require 'tests.helpers.mock_utils'

describe("tungsten.util.insert_result", function()
  local insert_result

  local original_vim_fn_getpos, original_vim_fn_split, original_vim_api_nvim_buf_set_text
  local selection_module_actual
  local original_get_visual_selection_func

  local modules_to_reset = {
    'tungsten.util.selection',
    'tungsten.util.insert_result',
  }

  before_each(function()
    _G.vim = _G.vim or {}
    _G.vim.fn = _G.vim.fn or {}
    _G.vim.api = _G.vim.api or {}

    original_vim_fn_getpos = _G.vim.fn.getpos
    original_vim_fn_split = _G.vim.fn.split
    original_vim_api_nvim_buf_set_text = _G.vim.api.nvim_buf_set_text

    _G.vim.fn.getpos = spy.new(function(marker)
      if marker == "'<" then return { 0, 1, 1, 0 } end
      if marker == "'>" then return { 0, 1, 1, 0 } end
      return { 0, 0, 0, 0 }
    end)

    _G.vim.api.nvim_buf_set_text = spy.new(function() end)

    _G.vim.fn.split = spy.new(function(str, sep)
      sep = sep or "\n"
      local res_tbl = {}
      if str == nil then return res_tbl end
      if str == "" then return {""} end
      local start_idx = 1
      while true do
        local sep_start, sep_end = string.find(str, sep, start_idx, true)
        if not sep_start then
          table.insert(res_tbl, string.sub(str, start_idx))
          break
        end
        table.insert(res_tbl, string.sub(str, start_idx, sep_start - 1))
        start_idx = sep_end + 1
      end
      return res_tbl
    end)

    mock_utils.reset_modules(modules_to_reset)

    selection_module_actual = require("tungsten.util.selection")
    original_get_visual_selection_func = selection_module_actual.get_visual_selection
    selection_module_actual.get_visual_selection = spy.new(function()
      return "mocked_selection"
    end)

    insert_result = require("tungsten.util.insert_result")
  end)

  after_each(function()
    _G.vim.fn.getpos = original_vim_fn_getpos
    _G.vim.fn.split = original_vim_fn_split
    _G.vim.api.nvim_buf_set_text = original_vim_api_nvim_buf_set_text

    if selection_module_actual and original_get_visual_selection_func then
      selection_module_actual.get_visual_selection = original_get_visual_selection_func
    end
    selection_module_actual = nil
    original_get_visual_selection_func = nil

    mock_utils.reset_modules(modules_to_reset)
  end)

  describe("insert_result(result_text)", function()
    describe("Single-Line Selection", function()
      it("should replace selection with 'selection = result_text' for a mid-line selection", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 5, 7, 0 } end
          if marker == "'>" then return { 0, 5, 13, 0 } end
          return {0,0,0,0}
        end)

        selection_module_actual.get_visual_selection = spy.new(function()
          return "s a te"
        end)

        local result = "my_result"
        insert_result.insert_result(result)

        assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(0, 4, 6, 4, 13, { "s a te = my_result" })
      end)

      it("should correctly handle selection at the beginning of the line", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 1, 0 } end
          if marker == "'>" then return { 0, 1, 5, 0 } end
          return {0,0,0,0}
        end)

        selection_module_actual.get_visual_selection = spy.new(function()
          return "This"
        end)

        insert_result.insert_result("res_begin")
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(0, 0, 0, 0, 5, { "This = res_begin" })
      end)

      it("should correctly handle selection at the end of the line", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 12, 0 } end
          if marker == "'>" then return { 0, 1, 16, 0 } end
          return {0,0,0,0}
        end)

        selection_module_actual.get_visual_selection = spy.new(function()
          return "test."
        end)

        insert_result.insert_result("res_end")
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(0, 0, 11, 0, 16, { "test. = res_end" })
      end)

      it("should append ' = ' when result_text is empty for single-line selection", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 3, 3, 0 } end
          if marker == "'>" then return { 0, 3, 6, 0 } end
          return {0,0,0,0}
        end)

        selection_module_actual.get_visual_selection = spy.new(function()
          return "foo"
        end)

        insert_result.insert_result("")
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(0, 2, 2, 2, 6, { "foo = " })
      end)
    end)

    describe("Multi-Line Selection", function()
      it("should replace selection with 'selection = result_text' for a multi-line selection", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 2, 3, 0 } end
          if marker == "'>" then return { 0, 4, 8, 0 } end
          return {0,0,0,0}
        end)

        selection_module_actual.get_visual_selection = spy.new(function()
          return "is is the first line.\nThis is the second line entirely selected.\nThis is"
        end)

        local result = "multi_res"
        insert_result.insert_result(result)

        assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
        local expected_replacement = {
          "is is the first line.",
          "This is the second line entirely selected.",
          "This is = multi_res",
        }
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(0, 1, 2, 3, 8, expected_replacement)
      end)

      it("should correctly handle result_text with newlines in multi-line selection", function()
          _G.vim.fn.getpos = spy.new(function(marker)
              if marker == "'<" then return { 0, 1, 1, 0 } end
              if marker == "'>" then return { 0, 2, 5, 0 } end
              return {0,0,0,0}
          end)

          selection_module_actual.get_visual_selection = spy.new(function()
              return "First line\nSeco"
          end)

          _G.vim.fn.split = spy.new(function(str, sep)
              sep = sep or "\n"
              local res_tbl = {}
              if str == nil then return res_tbl end
              if str == "" then return {""} end
              local start_idx = 1
              while true do
                local sep_start, sep_end = string.find(str, sep, start_idx, true)
                if not sep_start then
                  table.insert(res_tbl, string.sub(str, start_idx))
                  break
                end
                table.insert(res_tbl, string.sub(str, start_idx, sep_start - 1))
                start_idx = sep_end + 1
              end
              return res_tbl
          end)

          local result_with_newline = "result\nwith new line"
          insert_result.insert_result(result_with_newline)

          assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
          local expected_replacement = {
              "First line",
              "Seco = result",
              "with new line",
          }
          assert.spy(_G.vim.fn.split).was.called_with("First line\nSeco = result\nwith new line", "\n")
          assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(0, 0, 0, 1, 5, expected_replacement)
      end)

      it("should handle result_text with newlines when original selection is single-line", function()
          _G.vim.fn.getpos = spy.new(function(marker)
              if marker == "'<" then return { 0, 1, 1, 0 } end
              if marker == "'>" then return { 0, 1, 7, 0 } end
              return {0,0,0,0}
          end)
          selection_module_actual.get_visual_selection = spy.new(function()
              return "Select"
          end)

          _G.vim.fn.split = spy.new(function(str, sep)
              sep = sep or "\n"
              local res_tbl = {}
              if str == nil then return res_tbl end
              if str == "" then return {""} end
              local start_idx = 1
              while true do
                local sep_start, sep_end = string.find(str, sep, start_idx, true)
                if not sep_start then
                  table.insert(res_tbl, string.sub(str, start_idx))
                  break
                end
                table.insert(res_tbl, string.sub(str, start_idx, sep_start - 1))
                start_idx = sep_end + 1
              end
              return res_tbl
          end)

          local result_with_newline = "new\nresult"
          insert_result.insert_result(result_with_newline)

          assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
          local expected_replacement = { "Select = new", "result" }
          assert.spy(_G.vim.fn.split).was.called_with("Select = new\nresult", "\n")
          assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(0, 0, 0, 0, 7, expected_replacement)
      end)
    end)

    describe("Edge Cases and No-ops", function()
      it("should do nothing if original selection and result_text are both empty", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 1, 0 } end
          if marker == "'>" then return { 0, 1, 1, 0 } end
          return {0,0,0,0}
        end)
        selection_module_actual.get_visual_selection = spy.new(function()
          return ""
        end)

        insert_result.insert_result("")

        assert.spy(_G.vim.api.nvim_buf_set_text).was_not.called()
      end)

      it("should handle selection of an empty line correctly (inserting result)", function()
          _G.vim.fn.getpos = spy.new(function(marker)
              if marker == "'<" then return { 0, 1, 1, 0 } end
              if marker == "'>" then return { 0, 1, 1, 0 } end
              return {0,0,0,0}
          end)

          selection_module_actual.get_visual_selection = spy.new(function()
              return ""
          end)

          insert_result.insert_result("res_empty_line")

          assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
          assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(0, 0, 0, 0, 1, { " = res_empty_line" })
      end)

      it("should insert only ' = ' if selection is not empty but result is empty", function()
          _G.vim.fn.getpos = spy.new(function(marker)
              if marker == "'<" then return { 0, 1, 1, 0 } end
              if marker == "'>" then return { 0, 1, 5, 0 } end
              return {0,0,0,0}
          end)
          selection_module_actual.get_visual_selection = spy.new(function()
              return "Text"
          end)

          insert_result.insert_result("")

          assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
          assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(0, 0, 0, 0, 5, { "Text = " })
      end)
    end)
  end)
end)
