-- tests/unit/domains/linear_algebra/init_spec.lua
-- Unit tests for the linear algebra domain initialization.
---------------------------------------------------------------------

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local spy = require 'luassert.spy'
local match = require 'luassert.match'
local vim_test_env = require 'tests.helpers.vim_test_env'

local function mock_lpeg_pattern(name)
  return { __is_mock_lpeg_pattern = true, name = name or "mock_pattern" }
end

describe("Tungsten Linear Algebra Domain: lua/tungsten/domains/linear_algebra/init.lua", function()
  local linear_algebra_domain

  local mock_registry_module
  local mock_config_module
  local mock_logger_module
  local mock_tokenizer_module
  local mock_matrix_rule_module
  local mock_vector_rule_module
  local mock_determinant_rule_module
  local mock_norm_rule_module
  local mock_smart_ss_module_module

  local original_require

  local modules_to_clear_from_cache = {
    'tungsten.domains.linear_algebra.init',
    'tungsten.core.registry',
    'tungsten.config',
    'tungsten.util.logger',
    'tungsten.core.tokenizer',
    'tungsten.domains.linear_algebra.rules.matrix',
    'tungsten.domains.linear_algebra.rules.vector',
    'tungsten.domains.linear_algebra.rules.determinant',
    'tungsten.domains.linear_algebra.rules.norm',
    'tungsten.domains.linear_algebra.rules.smart_supersub',
  }

  local function clear_modules_from_cache_func()
    for _, name in ipairs(modules_to_clear_from_cache) do
      package.loaded[name] = nil
    end
  end

  before_each(function()

    mock_registry_module = { register_grammar_contribution = spy.new(function() end) }
    mock_config_module = { debug = false }
    mock_logger_module = {
      notify = spy.new(function() end),
      levels = { DEBUG = "DEBUG_LEVEL", INFO = "INFO_LEVEL", WARN = "WARN_LEVEL", ERROR = "ERROR_LEVEL" }
    }
    mock_tokenizer_module = {
        intercal_command = mock_lpeg_pattern("MockedIntercalCommand")
    }
    mock_matrix_rule_module = mock_lpeg_pattern("MatrixRule")
    mock_vector_rule_module = mock_lpeg_pattern("VectorRule")
    mock_determinant_rule_module = mock_lpeg_pattern("DeterminantRule")
    mock_norm_rule_module = mock_lpeg_pattern("NormRule")
    mock_smart_ss_module_module = {
        SmartSupSub = mock_lpeg_pattern("SmartSupSubRule"),
        SmartUnary = mock_lpeg_pattern("SmartUnaryRule")
    }

    original_require = _G.require
    _G.require = function(module_path)
      if module_path == 'tungsten.core.registry' then return mock_registry_module end
      if module_path == 'tungsten.config' then return mock_config_module end
      if module_path == 'tungsten.util.logger' then return mock_logger_module end
      if module_path == 'tungsten.core.tokenizer' then return mock_tokenizer_module end
      if module_path == 'tungsten.domains.linear_algebra.rules.matrix' then return mock_matrix_rule_module end
      if module_path == 'tungsten.domains.linear_algebra.rules.vector' then return mock_vector_rule_module end
      if module_path == 'tungsten.domains.linear_algebra.rules.determinant' then return mock_determinant_rule_module end
      if module_path == 'tungsten.domains.linear_algebra.rules.norm' then return mock_norm_rule_module end
      if module_path == 'tungsten.domains.linear_algebra.rules.smart_supersub' then return mock_smart_ss_module_module end
      if package.loaded[module_path] then return package.loaded[module_path] end
      return original_require(module_path)
    end

    clear_modules_from_cache_func()
    linear_algebra_domain = require("tungsten.domains.linear_algebra.init")
  end)

  after_each(function()
    _G.require = original_require

    if mock_registry_module and mock_registry_module.register_grammar_contribution and mock_registry_module.register_grammar_contribution.clear then
      mock_registry_module.register_grammar_contribution:clear()
    end
    if mock_logger_module and mock_logger_module.notify and mock_logger_module.notify.clear then
      mock_logger_module.notify:clear()
    end

    clear_modules_from_cache_func()

    if vim_test_env and vim_test_env.teardown then
      vim_test_env.teardown()
    elseif vim_test_env and vim_test_env.cleanup then
      vim_test_env.cleanup()
    end
  end)

  describe("get_metadata()", function()
    it("should return a table", function()
      assert.is_table(linear_algebra_domain.get_metadata())
    end)

    it("should return metadata with the correct name", function()
      local metadata = linear_algebra_domain.get_metadata()
      assert.are.equal("linear_algebra", metadata.name)
    end)

    it("should return metadata with the correct priority", function()
      local metadata = linear_algebra_domain.get_metadata()
      assert.are.equal(120, metadata.priority)
    end)

    it("should return metadata with correct dependencies", function()
      local metadata = linear_algebra_domain.get_metadata()
      assert.is_table(metadata.dependencies)
      assert.are.same({"arithmetic"}, metadata.dependencies)
    end)

    it("should return metadata with correct overrides table", function()
      local metadata = linear_algebra_domain.get_metadata()
      assert.is_table(metadata.overrides)
      assert.are.same({"SupSub", "Unary"}, metadata.overrides)
    end)

    it("should return metadata with the correct 'provides' table", function()
      local metadata = linear_algebra_domain.get_metadata()
      assert.is_table(metadata.provides)
      local expected_provides = {
        "Matrix",
        "Vector",
        "Determinant",
        "Norm",
        "SmartSupSub",
        "SmartUnary",
      }
      assert.are.same(expected_provides, metadata.provides)
    end)
  end)

  describe("init_grammar()", function()
    local expected_domain_name
    local expected_domain_priority

    before_each(function()
      expected_domain_name = "linear_algebra"
      expected_domain_priority = 120
      if mock_registry_module and mock_registry_module.register_grammar_contribution and mock_registry_module.register_grammar_contribution.clear then
        mock_registry_module.register_grammar_contribution:clear()
      end
       if mock_logger_module and mock_logger_module.notify and mock_logger_module.notify.clear then
        mock_logger_module.notify:clear()
      end
    end)

    local rules_to_test = {
      { name = "Matrix", rule_module_func = function() return mock_matrix_rule_module end, category = "AtomBaseItem" },
      { name = "Vector", rule_module_func = function() return mock_vector_rule_module end, category = "AtomBaseItem" },
      { name = "Determinant", rule_module_func = function() return mock_determinant_rule_module end, category = "AtomBaseItem" },
      { name = "Norm", rule_module_func = function() return mock_norm_rule_module end, category = "AtomBaseItem" },
      { name = "SupSub", rule_module_func = function() return mock_smart_ss_module_module.SmartSupSub end, category = "SupSub" },
      { name = "Unary", rule_module_func = function() return mock_smart_ss_module_module.SmartUnary end, category = "Unary" },
      { name = "IntercalCommand", rule_module_func = function() return mock_tokenizer_module.intercal_command end, category = "AtomBaseItem" }
    }

    for _, rule_info in ipairs(rules_to_test) do
      it("should call registry.register_grammar_contribution for " .. rule_info.name .. " rule", function()
        linear_algebra_domain.init_grammar()
        assert.spy(mock_registry_module.register_grammar_contribution).was.called_with(
          expected_domain_name,
          expected_domain_priority,
          rule_info.name,
          rule_info.rule_module_func(),
          rule_info.category
        )
      end)
    end

    it("should call registry.register_grammar_contribution the correct number of times", function()
      linear_algebra_domain.init_grammar()
      assert.spy(mock_registry_module.register_grammar_contribution).was.called(#rules_to_test)
    end)

    describe("Debug Logging", function()

      it("should log 'Initializing grammar contributions...' if config.debug is true", function()
        mock_config_module.debug = true
        linear_algebra_domain.init_grammar()
        assert.spy(mock_logger_module.notify).was.called_with(
          "Linear Algebra Domain: Initializing grammar contributions...",
          mock_logger_module.levels.DEBUG,
          { title = "Tungsten Debug" }
        )
      end)

      it("should log 'Grammar contributions registered.' with all provided rule names if config.debug is true", function()
        mock_config_module.debug = true
        linear_algebra_domain.init_grammar()
        local metadata = linear_algebra_domain.get_metadata()
        local expected_log_message = "Linear Algebra Domain: Grammar contributions registered for: " .. table.concat(metadata.provides, ", ")
        assert.spy(mock_logger_module.notify).was.called_with(
          expected_log_message,
          mock_logger_module.levels.DEBUG,
          { title = "Tungsten Debug" }
        )
      end)

      it("should not log debug messages if config.debug is false", function()
        mock_config_module.debug = false
        linear_algebra_domain.init_grammar()
        local notify_calls = mock_logger_module.notify.calls
        local found_initializing_msg = false
        local found_registered_msg = false
        for _, call in ipairs(notify_calls) do
          if type(call.vals[1]) == "string" then
            if call.vals[1]:find("Linear Algebra Domain: Initializing grammar contributions...", 1, true) then
              found_initializing_msg = true
            end
            if call.vals[1]:find("Linear Algebra Domain: Grammar contributions registered for:", 1, true) then
              found_registered_msg = true
            end
          end
        end
        assert.is_false(found_initializing_msg, "Should not have logged 'Initializing grammar contributions...' when debug is false")
        assert.is_false(found_registered_msg, "Should not have logged 'Grammar contributions registered.' when debug is false")
      end)
    end)
  end)
end)
