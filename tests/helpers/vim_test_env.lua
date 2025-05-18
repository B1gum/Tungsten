-- tests/helpers/vim_test_env.lua
local spy = require('luassert.spy')

local M = {}

local original_vim_global = _G.vim
local original_pcall_global = _G.pcall

M.mocked_vim = {
  api = {},
  fn = {},
  loop = {},
  log = {
    levels = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 }
  },
  tbl_isempty = function(tbl)
    return next(tbl) == nil
  end,
  notify = spy.new(function() end)
}

function M.setup(custom_mocks)
  _G.vim = M.mocked_vim

  if custom_mocks then
    for main_key, main_value in pairs(custom_mocks) do
      if type(main_value) == 'table' and _G.vim[main_key] and type(_G.vim[main_key]) == 'table' then
        for sub_key, sub_value in pairs(main_value) do
          _G.vim[main_key][sub_key] = sub_value
        end
      else
        _G.vim[main_key] = main_value
      end
    end
  end

  if not (_G.vim.api.nvim_create_user_command and _G.vim.api.nvim_create_user_command.is_spy) then
     _G.vim.api.nvim_create_user_command = spy.new(function() end)
  end
   if not (_G.vim.api.nvim_get_current_buf and _G.vim.api.nvim_get_current_buf.is_spy) then
    _G.vim.api.nvim_get_current_buf = spy.new(function() return 1 end)
  end
  if not (_G.vim.fn.jobstart and _G.vim.fn.jobstart.is_spy) then
    _G.vim.fn.jobstart = spy.new(function() return 1 end)
  end
   if not (_G.vim.loop.now and _G.vim.loop.now.is_spy) then
    _G.vim.loop.now = spy.new(function() return 1234567890 end)
  end
end

function M.teardown()
  _G.vim = original_vim_global
  _G.pcall = original_pcall_global
end

return M
