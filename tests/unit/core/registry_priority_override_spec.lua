local spy = require('luassert.spy')
local test_env = require('tests.helpers.vim_test_env')

describe("Registry priority override", function()
  local wolfram_backend
  local registry
  local config
  local logger
  local render_mod
  local original_require
  local mock_modules

  before_each(function()
    mock_modules = {}
    package.loaded['tungsten.backends.wolfram'] = nil
    package.loaded['tungsten.config'] = nil
    package.loaded['tungsten.core.registry'] = nil
    package.loaded['tungsten.util.logger'] = nil
    package.loaded['tungsten.core.render'] = nil

    config = require('tungsten.config')
    registry = require('tungsten.core.registry')
    logger = require('tungsten.util.logger')
    render_mod = require('tungsten.core.render')

    logger_notify_spy = spy.new(function() end)
    logger.notify = logger_notify_spy
    logger.debug = function(t,m) logger_notify_spy(m, logger.levels.DEBUG,{title=t}) end
    logger.info = function(t,m) logger_notify_spy(m, logger.levels.INFO,{title=t}) end
    logger.warn = function(t,m) logger_notify_spy(m, logger.levels.WARN,{title=t}) end
    logger.error = function(t,m) logger_notify_spy(m, logger.levels.ERROR,{title=t}) end

    render_spy = spy.new(function(ast, handlers)
      local h = handlers[ast.type]
      return h and h(ast) or nil
    end)
    render_mod.render = render_spy

    mock_modules["tungsten.backends.wolfram.domains.low_domain"] = {
      handlers = { op = spy.new(function() return "LOW" end) }
    }
    mock_modules["tungsten.backends.wolfram.domains.high_domain"] = {
      handlers = { op = spy.new(function() return "HIGH" end) }
    }

    original_require = _G.require
    _G.require = function(module_path)
      if module_path == 'tungsten.config' then return config end
      if module_path == 'tungsten.core.registry' then return registry end
      if module_path == 'tungsten.util.logger' then return logger end
      if module_path == 'tungsten.core.render' then return render_mod end
      if mock_modules[module_path] then return mock_modules[module_path] end
      return original_require(module_path)
    end

    test_env.set_plugin_config({'domains'}, { low_domain = 200, high_domain = 50 })

    wolfram_backend = require('tungsten.backends.wolfram')
  end)

  after_each(function()
    _G.require = original_require
    test_env.restore_plugin_configs()
  end)

  it("uses handler from domain with higher user priority", function()
    wolfram_backend.reload_handlers()
    local result = wolfram_backend.ast_to_wolfram({ type = 'op' })
    local low_spy = mock_modules["tungsten.backends.wolfram.domains.low_domain"].handlers.op
    local high_spy = mock_modules["tungsten.backends.wolfram.domains.high_domain"].handlers.op
    assert.spy(low_spy).was.called(1)
    assert.spy(high_spy).was_not.called()
    assert.are.equal("LOW", result)
    assert.are.equal(200, registry.get_domain_priority('low_domain'))
    assert.are.equal(50, registry.get_domain_priority('high_domain'))
  end)
end)

