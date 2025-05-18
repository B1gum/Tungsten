-- tests/unit/domains/calculus/init_spec.lua
-- Verifies the init.lua file for the calculus module
------------------------------------------------------
package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local spy = require('luassert.spy')

local mock_logger
local mock_config

local original_require = _G.require

describe("Tungsten Calculus Domain Initialization", function()
  local calculus_domain_module

  before_each(function()
    mock_logger = {
      notify = spy.new(function() end),
      levels = { DEBUG = "debug_level", INFO = "info_level", WARN = "warn_level", ERROR = "error_level" }
    }
    mock_config = {
      debug = false
    }

    _G.require = function(module_name)
      if module_name == "tungsten.util.logger" then
        return mock_logger
      elseif module_name == "tungsten.config" then
        return mock_config
      end
      return original_require(module_name)
    end

    package.loaded["tungsten.domains.calculus"] = nil
    calculus_domain_module = require("tungsten.domains.calculus")
  end)

  after_each(function()
    _G.require = original_require
  end)

  it("should be a loadable module returning a table", function()
    assert.is_table(calculus_domain_module, "Calculus domain module should be a table.")
  end)

  it("should provide a 'get_metadata' function", function()
    assert.is_function(calculus_domain_module.get_metadata, "Module should have a get_metadata function.")
  end)

  it("should return correct metadata structure from 'get_metadata'", function()
    local metadata = calculus_domain_module.get_metadata()
    assert.is_table(metadata, "Metadata should be a table.")
    assert.are.same("calculus", metadata.name, "Metadata name should be 'calculus'.")
    assert.is_number(metadata.priority, "Metadata priority should be a number.")
    assert.are.same(150, metadata.priority, "Metadata priority should be 150.")
    assert.is_table(metadata.dependencies, "Metadata dependencies should be a table.")
    assert.is_table(metadata.provides, "Metadata provides should be a table.")
  end)

  it("should provide an 'init_grammar' function", function()
    assert.is_function(calculus_domain_module.init_grammar, "Module should have an init_grammar function.")
  end)

  it("should log during 'init_grammar' if debug is enabled", function()
    mock_config.debug = true
    calculus_domain_module.init_grammar()
    assert.spy(mock_logger.notify).was.called()
    assert.spy(mock_logger.notify).was.called_with(
      "Calculus Domain: Initializing grammar contributions...",
      mock_logger.levels.DEBUG,
      { title = "Tungsten Debug" }
    )
  end)
end)
