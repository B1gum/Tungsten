-- tests/unit/util/insert_result_spec.lua
-- Unit tests for the insert_result utility function.
---------------------------------------------------------------------

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local spy = require 'luassert.spy'
local vim_test_env = require 'tests.helpers.vim_test_env'

describe("tungsten.util.insert_result", function()
  local insert_result

  local original_vim_fn_getpos, original_vim_fn_split, original_vim_api_nvim_buf_set_text

  local mock_selection_module
  local original_require

  local modules_to_clear_from_cache = {
    'tungsten.util.selection',
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

    mock_selection_module = {
      get_visual_selection = spy.new(function()
        return "mocked_selection"
      end)
    }

    original_require = _G.require
    _G.require = function(module_path)
      if module_path == 'tungsten.util.selection' then
        return mock_selection_module
      end
      if package.loaded[module_path] then
        return package.loaded[module_path]
      end
      return original_require(module_path)
    end

    clear_modules_from_cache_func()

    insert_result = require("tungsten.util.insert_result")
  end)

  after_each(function()
    if _G.vim.fn.getpos and type(_G.vim.fn.getpos) == "table" and _G.vim.fn.getpos.clear then _G.vim.fn.getpos:clear() end
    if _G.vim.fn.split and type(_G.vim.fn.split) == "table" and _G.vim.fn.split.clear then _G.vim.fn.split:clear() end
    if _G.vim.api.nvim_buf_set_text and type(_G.vim.api.nvim_buf_set_text) == "table" and _G.vim.api.nvim_buf_set_text.clear then _G.vim.api.nvim_buf_set_text:clear() end

    if mock_selection_module and mock_selection_module.get_visual_selection and mock_selection_module.get_visual_selection.clear then
      mock_selection_module.get_visual_selection:clear()
    end

    _G.vim.fn.getpos = original_vim_fn_getpos
    _G.vim.fn.split = original_vim_fn_split
    _G.vim.api.nvim_buf_set_text = original_vim_api_nvim_buf_set_text

    _G.require = original_require
    clear_modules_from_cache_func()

    if vim_test_env and vim_test_env.teardown then
      vim_test_env.teardown()
    elseif vim_test_env and vim_test_env.cleanup then
      vim_test_env.cleanup()
    end
  end)

  describe("insert_result(result_text)", function()
    describe("Single-Line Selection", function()
      it("should replace selection with 'selection = result_text' for a mid-line selection", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 5, 7, 0 } end
          if marker == "'>" then return { 0, 5, 13, 0 } end
          return {0,0,0,0}
        end)

        mock_selection_module.get_visual_selection = spy.new(function()
          return "s a te"
        end)

        local result = "my_result"
        insert_result.insert_result(result)

        assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(1, 4, 0, 4, 6, { "s a te = my_result" })
      end)

      it("should correctly handle selection at the beginning of the line", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 1, 0 } end
          if marker == "'>" then return { 0, 1, 5, 0 } end
          return {0,0,0,0}
        end)

        mock_selection_module.get_visual_selection = spy.new(function()
          return "This"
        end)

        insert_result.insert_result("res_begin")
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(1, 0, 0, 0, 0, { "This = res_begin" })
      end)

      it("should correctly handle selection at the end of the line", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 12, 0 } end
          if marker == "'>" then return { 0, 1, 16, 0 } end
          return {0,0,0,0}
        end)

        mock_selection_module.get_visual_selection = spy.new(function()
          return "test."
        end)

        insert_result.insert_result("res_end")
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(1, 0, 0, 0, 11, { "test. = res_end" })
      end)

      it("should append ' = ' when result_text is empty for single-line selection", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 3, 3, 0 } end
          if marker == "'>" then return { 0, 3, 6, 0 } end
          return {0,0,0,0}
        end)

        mock_selection_module.get_visual_selection = spy.new(function()
          return "foo"
        end)

        insert_result.insert_result("")
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(1, 2, 0, 2, 2, { "foo = " })
      end)
    end)

    describe("Multi-Line Selection", function()
      it("should replace selection with 'selection = result_text' for a multi-line selection", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 2, 3, 0 } end
          if marker == "'>" then return { 0, 4, 8, 0 } end
          return {0,0,0,0}
        end)

        mock_selection_module.get_visual_selection = spy.new(function()
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
        assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(1, 1, 2, 3, 0, expected_replacement)
      end)

      it("should correctly handle result_text with newlines in multi-line selection", function()
          _G.vim.fn.getpos = spy.new(function(marker)
              if marker == "'<" then return { 0, 1, 1, 0 } end
              if marker == "'>" then return { 0, 2, 5, 0 } end
              return {0,0,0,0}
          end)

          mock_selection_module.get_visual_selection = spy.new(function()
              return "First line\nSeco"
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
          assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(1, 0, 0, 1, 0, expected_replacement)
      end)

      it("should handle result_text with newlines when original selection is single-line", function()
          _G.vim.fn.getpos = spy.new(function(marker)
              if marker == "'<" then return { 0, 1, 1, 0 } end
              if marker == "'>" then return { 0, 1, 7, 0 } end
              return {0,0,0,0}
          end)
          mock_selection_module.get_visual_selection = spy.new(function()
              return "Select"
          end)

          local result_with_newline = "new\nresult"
          insert_result.insert_result(result_with_newline)

          assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
          local expected_replacement = { "Select = new", "result" }
          assert.spy(_G.vim.fn.split).was.called_with("Select = new\nresult", "\n")
          assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(1, 0, 0, 0, 0, expected_replacement)
      end)
    end)

    describe("Edge Cases and No-ops", function()
      it("should do nothing if original selection and result_text are both empty", function()
        _G.vim.fn.getpos = spy.new(function(marker)
          if marker == "'<" then return { 0, 1, 1, 0 } end
          if marker == "'>" then return { 0, 1, 1, 0 } end
          return {0,0,0,0}
        end)
        mock_selection_module.get_visual_selection = spy.new(function()
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

          mock_selection_module.get_visual_selection = spy.new(function()
              return ""
          end)

          insert_result.insert_result("res_empty_line")

          assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
          assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(1, 0, 0, 0, 0, { " = res_empty_line" })
      end)

      it("should insert only ' = ' if selection is not empty but result is empty", function()
          _G.vim.fn.getpos = spy.new(function(marker)
              if marker == "'<" then return { 0, 1, 1, 0 } end
              if marker == "'>" then return { 0, 1, 5, 0 } end
              return {0,0,0,0}
          end)
          mock_selection_module.get_visual_selection = spy.new(function()
              return "Text"
          end)

          insert_result.insert_result("")

          assert.spy(_G.vim.api.nvim_buf_set_text).was.called(1)
          assert.spy(_G.vim.api.nvim_buf_set_text).was.called_with(1, 0, 0, 0, 0, { "Text = " })
      end)
    end)
  end)
end)
