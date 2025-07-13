local mock_utils = require('tests.helpers.mock_utils')
local vim_test_env = require('tests.helpers.vim_test_env')
local spy = require 'luassert.spy'

local modules_to_reset = {
  'tungsten',
  'tungsten.config',
  'tungsten.core.commands',
  'tungsten.core',
  'tungsten.ui.which_key',
  'tungsten.ui.commands',
  'tungsten.ui',
  'which-key',
  'telescope',
  'telescope.pickers',
  'telescope.finders',
  'telescope.sorters',
  'telescope.actions',
  'telescope.actions.state',
}

local function reset_all()
  mock_utils.reset_modules(modules_to_reset)
end

before_each(function()
  reset_all()
end)

after_each(function()
  reset_all()
  vim.notify = vim.notify
  vim_test_env.cleanup()
end)

describe("Optional integrations", function()
  describe("Which-Key integration", function()
    it("loads without error when which-key is absent", function()
      package.loaded['which-key'] = nil
      local ok = pcall(require, 'tungsten.ui.which_key')
      assert.is_true(ok)
    end)

    it("registers mappings when which-key is present", function()
      local wk_mock = mock_utils.create_empty_mock_module('which-key', { 'add' })
      mock_utils.reset_modules({ 'tungsten.ui.which_key' })
      local wk_module = require('tungsten.ui.which_key')
      assert.spy(wk_mock.add).was.called(1)
      assert.spy(wk_mock.add).was.called_with(wk_module.mappings)
    end)
  end)

  describe("Telescope integration", function()
    it("warns when telescope is missing", function()
      package.loaded['telescope'] = nil
      local notify_spy = spy.new(function() end)
      vim.notify = notify_spy
      local orig_schedule = vim.schedule
      vim.schedule = function(cb) cb() end

      require('tungsten').setup()

      local ok, err = pcall(vim.cmd, 'TungstenPalette')
      assert.is_true(ok, err)
      assert.spy(notify_spy).was.called(1)
      vim.schedule = orig_schedule
    end)
  end)
end)

