-- tests/unit/result_hook_spec.lua

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local spy = require 'luassert.spy'

describe("result hook", function()
  local insert_result
  local tungsten
  local hook_spy
  local exec_autocmd_spy
  local orig = {}

  before_each(function()
    for _,mod in ipairs({'tungsten.util.insert_result','tungsten'}) do
      package.loaded[mod] = nil
    end

    _G.vim = _G.vim or {}
    _G.vim.fn = _G.vim.fn or {}
    _G.vim.api = _G.vim.api or {}

    orig.getpos = _G.vim.fn.getpos
    orig.split = _G.vim.fn.split
    orig.mode = _G.vim.fn.mode
    orig.buf_set_text = _G.vim.api.nvim_buf_set_text
    orig.buf_get_lines = _G.vim.api.nvim_buf_get_lines
    orig.exec_autocmds = _G.vim.api.nvim_exec_autocmds

    _G.vim.fn.getpos = function(_) return {0,1,1,0} end
    _G.vim.fn.split = function(str) return {str} end
    _G.vim.fn.mode = function() return 'v' end
    _G.vim.api.nvim_buf_set_text = function() end
    _G.vim.api.nvim_buf_get_lines = function() return {""} end
    exec_autocmd_spy = spy.new(function() end)
    _G.vim.api.nvim_exec_autocmds = exec_autocmd_spy

    tungsten = require('tungsten')
    hook_spy = spy.new(function() end)
    tungsten.config.hooks = { on_result = hook_spy }

    insert_result = require('tungsten.util.insert_result')
  end)

  after_each(function()
    if orig.getpos then _G.vim.fn.getpos = orig.getpos end
    if orig.split then _G.vim.fn.split = orig.split end
    if orig.mode then _G.vim.fn.mode = orig.mode end
    if orig.buf_set_text then _G.vim.api.nvim_buf_set_text = orig.buf_set_text end
    if orig.buf_get_lines then _G.vim.api.nvim_buf_get_lines = orig.buf_get_lines end
    if orig.exec_autocmds then _G.vim.api.nvim_exec_autocmds = orig.exec_autocmds end
  end)

  it("calls user hook and autocmd", function()
    insert_result.insert_result("42", " = ", {0,1,1,0}, {0,1,1,0}, "x")
    assert.spy(hook_spy).was.called_with("42")
    assert.spy(exec_autocmd_spy).was.called()
  end)
end)

