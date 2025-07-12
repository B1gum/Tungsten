local mock_utils = require('tests.helpers.mock_utils')
local vim_test_env = require('tests.helpers.vim_test_env')

local modules_to_reset = {
  'tungsten.config',
  'tungsten.ui.which_key',
  'which-key',
}

local function reset_all()
  mock_utils.reset_modules(modules_to_reset)
end

before_each(function()
  reset_all()
end)

after_each(function()
  reset_all()
  vim_test_env.cleanup()
end)

describe("which_key configuration", function()
  it("skips registering mappings when disabled", function()
    local wk_mock = mock_utils.create_empty_mock_module('which-key', { 'register' })
    require('tungsten.config')
    vim_test_env.set_plugin_config({ 'enable_default_mappings' }, false)
    mock_utils.reset_modules({ 'tungsten.ui.which_key' })
    require('tungsten.ui.which_key')
    assert.spy(wk_mock.register).was.not_called()
  end)
end)

