-- tests/unit/util/insert_result_spec.lua
-- Unit tests for the insert_result utility function.
---------------------------------------------------------------------

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local spy = require 'luassert.spy'
local vim_test_env = require 'tests.helpers.vim_test_env'

describe("tungsten.util.insert_result", function()
  local insert_result

  local original_vim_fn_getpos, original_vim_fn_split, original_vim_api_nvim_buf_set_text, original_vim_fn_mode
  local original_vim_api_nvim_buf_get_lines

  local modules_to_clear_from_cache = {
    'tungsten.util.insert_result',
  }

  local function clear_modules_from_cache_func()
    for _, name in ipairs(modules_to_clear_from_cache) do
      package.loaded[name] = nil
    end
  end

  before_each(function()
    _G.vim = _G.vim or {}
    _G.vim.fn = _G.vim.fn or {}
    _G.vim.api = _G.vim.api or {}

    original_vim_fn_getpos = _G.vim.fn.getpos
    original_vim_fn_split = _G.vim.fn.split
    original_vim_api_nvim_buf_set_text = _G.vim.api.nvim_buf_set_text
    original_vim_fn_mode = _G.vim.fn.mode
    original_vim_api_nvim_buf_get_lines = _G.vim.api.nvim_buf_get_lines

    _G.vim.fn.getpos = spy.new(function(marker)
      if marker == "'<" then return { 0, 1, 1, 0 } end
      if marker == "'>" then return { 0, 1, 1, 0 } end
      return { 0, 0, 0, 0 }
    end)

    _G.vim.api.nvim_buf_set_text = spy.new(function() end)

    _G.vim.api.nvim_buf_get_lines = spy.new(function()
      return { "This is a sufficiently long line of text for all testing purposes to avoid out-of-bounds errors." }
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

    _G.vim.fn.mode = spy.new(function(idx)
      if idx == 1 then return 'v' end
      return original_vim_fn_mode and original_vim_fn_mode(idx) or 'n'
    end)

    clear_modules_from_cache_func()
    insert_result = require("tungsten.util.insert_result")
  end)

  after_each(function()
    if _G.vim.fn.getpos and type(_G.vim.fn.getpos) == "table" and _G.vim.fn.getpos.clear then _G.vim.fn.getpos:clear() end
    if _G.vim.fn.split and type(_G.vim.fn.split) == "table" and _G.vim.fn.split.clear then _G.vim.fn.split:clear() end
    if _G.vim.api.nvim_buf_set_text and type(_G.vim.api.nvim_buf_set_text) == "table" and _G.vim.api.nvim_buf_set_text.clear then _G.vim.api.nvim_buf_set_text:clear() end
    if _G.vim.fn.mode and type(_G.vim.fn.mode) == "table" and _G.vim.fn.mode.clear then _G.vim.fn.mode:clear() end
    if _G.vim.api.nvim_buf_get_lines and type(_G.vim.api.nvim_buf_get_lines) == "table" and _G.vim.api.nvim_buf_get_lines.clear then _G.vim.api.nvim_buf_get_lines:clear() end

    _G.vim.fn.getpos = original_vim_fn_getpos
    _G.vim.fn.split = original_vim_fn_split
    _G.vim.api.nvim_buf_set_text = original_vim_api_nvim_buf_set_text
    _G.vim.fn.mode = original_vim_fn_mode
    _G.vim.api.nvim_buf_get_lines = original_vim_api_nvim_buf_get_lines

    clear_modules_from_cache_func()

    if vim_test_env and vim_test_env.teardown then
      vim_test_env.teardown()
    elseif vim_test_env and vim_test_env.cleanup then
      vim_test_env.cleanup()
    end
  end)

  describe("insert_result(result_text, separator, start_pos, end_pos, selection_text)", function()
    describe("Single-Line Selection", function()
      it("should replace selection with 'selection = result_text' for a mid-line selection", function()
        local mock_start_pos = { 0, 5, 7, 0 }
        local mock_end_pos = { 0, 5, 13, 0 }
        local mock_selection = "s a te"
        local result = "my_result"

        insert_result.insert_result(result, " = ", mock_start_pos, mock_end_pos, mock_selection)

        assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(0, 4, 6, 4, 13, { "s a te = my_result" })
      end)

      it("should correctly handle selection at the beginning of the line", function()
        local mock_start_pos = { 0, 1, 1, 0 }
        local mock_end_pos = { 0, 1, 5, 0 }
        local mock_selection = "This"

        insert_result.insert_result("res_begin", " = ", mock_start_pos, mock_end_pos, mock_selection)
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(0, 0, 0, 0, 5, { "This = res_begin" })
      end)

      it("should correctly handle selection at the end of the line", function()
        local mock_start_pos = { 0, 1, 12, 0 } 
        local mock_end_pos = { 0, 1, 16, 0 }
        local mock_selection = "test."

        insert_result.insert_result("res_end", " = ", mock_start_pos, mock_end_pos, mock_selection)
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(0, 0, 11, 0, 16, { "test. = res_end" })
      end)

      it("should append ' = ' when result_text is empty for single-line selection", function()
        local mock_start_pos = { 0, 3, 3, 0 }
        local mock_end_pos = { 0, 3, 6, 0 }
        local mock_selection = "foo"

        insert_result.insert_result("", " = ", mock_start_pos, mock_end_pos, mock_selection)
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(0, 2, 2, 2, 6, { "foo = " })
      end)
    end)

    describe("Multi-Line Selection", function()
      it("should replace selection with 'selection = result_text' for a multi-line selection", function()
        local mock_start_pos = { 0, 2, 3, 0 }
        local mock_end_pos = { 0, 4, 8, 0 }
        local mock_selection = "is is the first line.\nThis is the second line entirely selected.\nThis is"
        local result = "multi_res"

        insert_result.insert_result(result, " = ", mock_start_pos, mock_end_pos, mock_selection)

        assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
        local expected_replacement = {
          "is is the first line.",
          "This is the second line entirely selected.",
          "This is = multi_res",
        }
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(0, 1, 2, 3, 8, expected_replacement)
      end)

      it("should correctly handle result_text with newlines in multi-line selection", function()
          local mock_start_pos = { 0, 1, 1, 0 }
          local mock_end_pos = { 0, 2, 5, 0 }
          local mock_selection = "First line\nSeco"
          local result_with_newline = "result\nwith new line"

          insert_result.insert_result(result_with_newline, " = ", mock_start_pos, mock_end_pos, mock_selection)

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
          local mock_start_pos = { 0, 1, 1, 0 }
          local mock_end_pos = { 0, 1, 7, 0 }
          local mock_selection = "Select"
          local result_with_newline = "new\nresult"

          insert_result.insert_result(result_with_newline, " = ", mock_start_pos, mock_end_pos, mock_selection)

          assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
          local expected_replacement = { "Select = new", "result" }
          assert.spy(_G.vim.fn.split).was.called_with("Select = new\nresult", "\n")
          assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(0, 0, 0, 0, 7, expected_replacement)
      end)
    end)

    describe("Edge Cases and No-ops", function()
      it("should do nothing if original selection and result_text are both empty", function()
        local mock_start_pos = { 0, 1, 1, 0 }
        local mock_end_pos = { 0, 1, 1, 0 }
        local mock_selection = ""

        insert_result.insert_result("", " = ", mock_start_pos, mock_end_pos, mock_selection)
        assert.spy(_G.vim.api.nvim_buf_set_text).was_not.called()
      end)

      it("should handle selection of an empty line correctly (inserting result)", function()
          local mock_start_pos = { 0, 1, 1, 0 }
          local mock_end_pos = { 0, 1, 1, 0 }
          local mock_selection = ""

          insert_result.insert_result("res_empty_line", " = ", mock_start_pos, mock_end_pos, mock_selection)

          assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
          assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(0, 0, 0, 0, 1, { " = res_empty_line" })
      end)

      it("should insert only ' = ' if selection is not empty but result is empty", function()
          local mock_start_pos = { 0, 1, 1, 0 }
          local mock_end_pos = { 0, 1, 5, 0 }
          local mock_selection = "Text"

          insert_result.insert_result("", " = ", mock_start_pos, mock_end_pos, mock_selection)

          assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
          assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(0, 0, 0, 0, 5, { "Text = " })
      end)
    end)
  end)
end)
