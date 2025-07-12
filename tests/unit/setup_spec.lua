-- tests/unit/setup_spec.lua
-- Tests for the Tungsten setup function

describe("tungsten.setup", function()
  local tungsten
  local defaults

  local function reload_modules()
    package.loaded['tungsten'] = nil
    package.loaded['tungsten.config'] = nil
    package.loaded['tungsten.core.commands'] = {}
    package.loaded['tungsten.ui.which_key'] = {}
    package.loaded['tungsten.ui'] = {}
    package.loaded['tungsten.core'] = {}
    defaults = require('tungsten.config')
    tungsten = require('tungsten')
  end

  before_each(reload_modules)
  after_each(reload_modules)

  it("keeps config unchanged with nil opts", function()
    local before = vim.deepcopy(tungsten.config)
    tungsten.setup()
    assert.are.same(before, tungsten.config)
    assert.are.same(before, require('tungsten.config'))
  end)

  it("keeps config unchanged with empty table", function()
    local before = vim.deepcopy(tungsten.config)
    tungsten.setup({})
    assert.are.same(before, tungsten.config)
  end)

  it("overrides defaults with user options", function()
    local snapshot = vim.deepcopy(defaults)
    tungsten.setup({ debug = true, wolfram_timeout_ms = 10 })
    local cfg = require('tungsten.config')
    assert.is_true(cfg.debug)
    assert.are.equal(10, cfg.wolfram_timeout_ms)
    assert.are.same(snapshot, defaults)
  end)

  it("throws error for invalid option type", function()
    assert.has_error(function() tungsten.setup(42) end, "tungsten.setup: options table expected")
  end)

  it("creates user commands from registry", function()
    local mock_registry = {
      commands = {
        { name = 'MockCmd', func = function() end, opts = { desc = 'mock' } },
      },
      register_command = function(self, cmd) table.insert(self.commands, cmd) end,
    }
    package.loaded['tungsten.core.registry'] = mock_registry

    local create_spy = require('luassert.spy').new(function() end)
    local orig_create = vim.api.nvim_create_user_command
    vim.api.nvim_create_user_command = create_spy

    tungsten.setup()

    for _, cmd in ipairs(mock_registry.commands) do
      local expected_opts = cmd.opts or { desc = cmd.desc }
      assert.spy(create_spy).was.called_with(cmd.name, cmd.func, expected_opts)
    end

    vim.api.nvim_create_user_command = orig_create
  end)
end)

