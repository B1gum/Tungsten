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
      local wk_mock = mock_utils.create_empty_mock_module('which-key', { 'register' })
      mock_utils.reset_modules({ 'tungsten.ui.which_key' })
      local wk_module = require('tungsten.ui.which_key')
      assert.spy(wk_mock.register).was.called(1)
      assert.spy(wk_mock.register).was.called_with(wk_module.mappings)
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
      assert.spy(notify_spy).was.called_with('Telescope not found. Install telescope.nvim for enhanced UI.', vim.log.levels.WARN)
      vim.schedule = orig_schedule
    end)

    it("uses telescope extension when available", function()
      local telescope_mock = { extensions = {} }
      telescope_mock.register_extension = spy.new(function(ext)
        telescope_mock.extensions.tungsten = ext.exports
      end)
      package.loaded['telescope'] = telescope_mock
      mock_utils.create_empty_mock_module('telescope.pickers', { 'new' })
      mock_utils.create_empty_mock_module('telescope.finders', { 'new_table' })
      mock_utils.create_empty_mock_module('telescope.sorters', { 'get_fuzzy_file' })
      mock_utils.create_empty_mock_module('telescope.actions', { 'close' })
      mock_utils.create_empty_mock_module('telescope.actions.state', { 'get_selected_entry' })
      local orig_schedule = vim.schedule
      vim.schedule = function(cb) cb() end

      require('tungsten').setup()

      local open_spy = spy.new(function() end)
      telescope_mock.extensions.tungsten.open = open_spy

      vim.cmd('TungstenPalette')

      assert.spy(open_spy).was.called(1)
      vim.schedule = orig_schedule
    end)
  end)
end)
