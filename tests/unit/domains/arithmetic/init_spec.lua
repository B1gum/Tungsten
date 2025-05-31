-- tests/unit/domains/arithmetic/init_spec.lua
-- Unit tests for the arithmetic domain initialization.
---------------------------------------------------------------------

local spy = require 'luassert.spy'
local match = require 'luassert.match'

local vim_test_env = require 'tests.helpers.vim_test_env'
if not vim_test_env then
  error("FATAL: require 'tests.helpers.vim_test_env' returned nil. Check path and file integrity.")
end

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local function mock_lpeg_pattern(name)
  return { __is_mock_lpeg_pattern = true, name = name or "mock_pattern" }
end

describe("Tungsten Arithmetic Domain: lua/tungsten/domains/arithmetic/init.lua", function()
  local arithmetic_domain

  local mock_registry_module
  local mock_config_module
  local mock_logger_module
  local mock_tokenizer_module
  local mock_fraction_rule_module
  local mock_sqrt_rule_module
  local mock_supersub_rules_module
  local mock_muldiv_rule_module
  local mock_addsub_rule_module
  local mock_trig_functions_module

  local original_require

  local modules_to_clear_from_cache = {
    'tungsten.domains.arithmetic.init',
    'tungsten.core.registry',
    'tungsten.config',
    'tungsten.util.logger',
    'tungsten.core.tokenizer',
    'tungsten.domains.arithmetic.rules.fraction',
    'tungsten.domains.arithmetic.rules.sqrt',
    'tungsten.domains.arithmetic.rules.supersub',
    'tungsten.domains.arithmetic.rules.muldiv',
    'tungsten.domains.arithmetic.rules.addsub',
    'tungsten.domains.arithmetic.rules.trig_functions',
  }

  local function clear_modules_from_cache_func()
    for _, name in ipairs(modules_to_clear_from_cache) do
      package.loaded[name] = nil
    end
  end

  before_each(function()
    mock_registry_module = {
      register_grammar_contribution = spy.new(function() end)
    }
    mock_config_module = {
      debug = false
    }
    mock_logger_module = {
      notify = spy.new(function() end),
      levels = { DEBUG = "DEBUG_LEVEL", INFO = "INFO_LEVEL" }
    }
    mock_tokenizer_module = {
      number = mock_lpeg_pattern("tokens_mod.number"),
      variable = mock_lpeg_pattern("tokens_mod.variable"),
      Greek = mock_lpeg_pattern("tokens_mod.Greek")
    }
    mock_fraction_rule_module = mock_lpeg_pattern("Fraction_rule")
    mock_sqrt_rule_module = mock_lpeg_pattern("Sqrt_rule")
    mock_muldiv_rule_module = mock_lpeg_pattern("MulDiv_rule")
    mock_addsub_rule_module = mock_lpeg_pattern("AddSub_rule")
    mock_supersub_rules_module = {
      SupSub = mock_lpeg_pattern("SS_rules_mod.SupSub"),
      Unary = mock_lpeg_pattern("SS_rules_mod.Unary")
    }
    mock_trig_functions_module = {
      SinRule = mock_lpeg_pattern("MockedSinRule_from_trig_module")
    }

    original_require = _G.require
    _G.require = function(module_path)
      if module_path == 'tungsten.core.registry' then return mock_registry_module end
      if module_path == 'tungsten.config' then return mock_config_module end
      if module_path == 'tungsten.util.logger' then return mock_logger_module end
      if module_path == 'tungsten.core.tokenizer' then return mock_tokenizer_module end
      if module_path == 'tungsten.domains.arithmetic.rules.fraction' then return mock_fraction_rule_module end
      if module_path == 'tungsten.domains.arithmetic.rules.sqrt' then return mock_sqrt_rule_module end
      if module_path == 'tungsten.domains.arithmetic.rules.supersub' then return mock_supersub_rules_module end
      if module_path == 'tungsten.domains.arithmetic.rules.muldiv' then return mock_muldiv_rule_module end
      if module_path == 'tungsten.domains.arithmetic.rules.addsub' then return mock_addsub_rule_module end
      if module_path == 'tungsten.domains.arithmetic.rules.trig_functions' then return mock_trig_functions_module end
      if package.loaded[module_path] then return package.loaded[module_path] end
      return original_require(module_path)
    end

    clear_modules_from_cache_func()
    arithmetic_domain = require("tungsten.domains.arithmetic.init")
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
      assert.is_table(arithmetic_domain.get_metadata())
    end)

    it("should return metadata with the correct name", function()
      local metadata = arithmetic_domain.get_metadata()
      assert.are.equal("arithmetic", metadata.name)
    end)

    it("should return metadata with the correct priority", function()
      local metadata = arithmetic_domain.get_metadata()
      assert.are.equal(100, metadata.priority)
    end)

    it("should return metadata with an empty dependencies table", function()
      local metadata = arithmetic_domain.get_metadata()
      assert.is_table(metadata.dependencies)
      assert.is_true(vim.tbl_isempty(metadata.dependencies))
    end)

    it("should return metadata with the correct 'provides' table", function()
      local metadata = arithmetic_domain.get_metadata()
      assert.is_table(metadata.provides)
      assert.are.same({ "AtomBaseItem", "SupSub", "Unary", "MulDiv", "AddSub", "Fraction", "Sqrt", "SinFunction" }, metadata.provides)
    end)
  end)

  describe("init_grammar()", function()
    local expected_domain_name
    local expected_domain_priority

    before_each(function()
      expected_domain_name = "arithmetic"
      expected_domain_priority = 100
      mock_registry_module.register_grammar_contribution:clear()
      mock_logger_module.notify:clear()
    end)

    it("should call registry.register_grammar_contribution for Number token", function()
      arithmetic_domain.init_grammar()
      assert.spy(mock_registry_module.register_grammar_contribution).was.called_with(
        expected_domain_name,
        expected_domain_priority,
        "Number",
        mock_tokenizer_module.number,
        "AtomBaseItem"
      )
    end)

    it("should call registry.register_grammar_contribution for Variable token", function()
      arithmetic_domain.init_grammar()
      assert.spy(mock_registry_module.register_grammar_contribution).was.called_with(
        expected_domain_name,
        expected_domain_priority,
        "Variable",
        mock_tokenizer_module.variable,
        "AtomBaseItem"
      )
    end)

    it("should call registry.register_grammar_contribution for Greek token", function()
      arithmetic_domain.init_grammar()
      assert.spy(mock_registry_module.register_grammar_contribution).was.called_with(
        expected_domain_name,
        expected_domain_priority,
        "Greek",
        mock_tokenizer_module.Greek,
        "AtomBaseItem"
      )
    end)

    it("should call registry.register_grammar_contribution for Fraction rule", function()
      arithmetic_domain.init_grammar()
      assert.spy(mock_registry_module.register_grammar_contribution).was.called_with(
        expected_domain_name,
        expected_domain_priority,
        "Fraction",
        mock_fraction_rule_module,
        "AtomBaseItem"
      )
    end)

    it("should call registry.register_grammar_contribution for Sqrt rule", function()
      arithmetic_domain.init_grammar()
      assert.spy(mock_registry_module.register_grammar_contribution).was.called_with(
        expected_domain_name,
        expected_domain_priority,
        "Sqrt",
        mock_sqrt_rule_module,
        "AtomBaseItem"
      )
    end)

    it("should call registry.register_grammar_contribution for SupSub rule", function()
      arithmetic_domain.init_grammar()
      assert.spy(mock_registry_module.register_grammar_contribution).was.called_with(
        expected_domain_name,
        expected_domain_priority,
        "SupSub",
        mock_supersub_rules_module.SupSub,
        "SupSub"
      )
    end)

    it("should call registry.register_grammar_contribution for Unary rule", function()
      arithmetic_domain.init_grammar()
      assert.spy(mock_registry_module.register_grammar_contribution).was.called_with(
        expected_domain_name,
        expected_domain_priority,
        "Unary",
        mock_supersub_rules_module.Unary,
        "Unary"
      )
    end)

    it("should call registry.register_grammar_contribution for MulDiv rule", function()
      arithmetic_domain.init_grammar()
      assert.spy(mock_registry_module.register_grammar_contribution).was.called_with(
        expected_domain_name,
        expected_domain_priority,
        "MulDiv",
        mock_muldiv_rule_module,
        "MulDiv"
      )
    end)

    it("should call registry.register_grammar_contribution for AddSub rule", function()
      arithmetic_domain.init_grammar()
      assert.spy(mock_registry_module.register_grammar_contribution).was.called_with(
        expected_domain_name,
        expected_domain_priority,
        "AddSub",
        mock_addsub_rule_module,
        "AddSub"
      )
    end)
    
    it("should call registry.register_grammar_contribution for SinFunction rule", function()
      arithmetic_domain.init_grammar()
      assert.spy(mock_registry_module.register_grammar_contribution).was.called_with(
        expected_domain_name,
        expected_domain_priority,
        "SinFunction",
        mock_trig_functions_module.SinRule,
        "AtomBaseItem"
      )
    end)

    it("should call registry.register_grammar_contribution the correct number of times (10)", function()
      arithmetic_domain.init_grammar()
      assert.spy(mock_registry_module.register_grammar_contribution).was.called(10)
    end)

    describe("Debug Logging", function()
      before_each(function()
          local current_original_require = _G.require
          _G.require = function(module_path)
            if module_path == 'tungsten.core.registry' then return mock_registry_module end
            if module_path == 'tungsten.config' then return mock_config_module end
            if module_path == 'tungsten.util.logger' then return mock_logger_module end
            if module_path == 'tungsten.core.tokenizer' then return mock_tokenizer_module end
            if module_path == 'tungsten.domains.arithmetic.rules.fraction' then return mock_fraction_rule_module end
            if module_path == 'tungsten.domains.arithmetic.rules.sqrt' then return mock_sqrt_rule_module end
            if module_path == 'tungsten.domains.arithmetic.rules.supersub' then return mock_supersub_rules_module end
            if module_path == 'tungsten.domains.arithmetic.rules.muldiv' then return mock_muldiv_rule_module end
            if module_path == 'tungsten.domains.arithmetic.rules.addsub' then return mock_addsub_rule_module end
            if module_path == 'tungsten.domains.arithmetic.rules.trig_functions' then return mock_trig_functions_module end
            if package.loaded[module_path] then return package.loaded[module_path] end
            return current_original_require(module_path)
          end

          package.loaded['tungsten.domains.arithmetic.init'] = nil
          arithmetic_domain = require("tungsten.domains.arithmetic.init")
      end)

      it("should log 'Initializing grammar contributions...' if config.debug is true", function()
        mock_config_module.debug = true
        arithmetic_domain.init_grammar()
        assert.spy(mock_logger_module.notify).was.called_with(
          "Arithmetic Domain: Initializing grammar contributions...",
          mock_logger_module.levels.DEBUG,
          { title = "Tungsten Debug" }
        )
      end)

      it("should log 'Grammar contributions registered.' if config.debug is true", function()
        mock_config_module.debug = true
        arithmetic_domain.init_grammar()
        assert.spy(mock_logger_module.notify).was.called_with(
          "Arithmetic Domain: Grammar contributions registered.",
          mock_logger_module.levels.DEBUG,
          { title = "Tungsten Debug" }
        )
      end)

      it("should not log debug messages if config.debug is false", function()
        mock_config_module.debug = false
        arithmetic_domain.init_grammar()

        local notify_calls = mock_logger_module.notify.calls
        local found_initializing_msg = false
        local found_registered_msg = false
        for _, call in ipairs(notify_calls) do
          if call.vals[1] == "Arithmetic Domain: Initializing grammar contributions..." then
            found_initializing_msg = true
          end
          if call.vals[1] == "Arithmetic Domain: Grammar contributions registered." then
            found_registered_msg = true
          end
        end
        assert.is_false(found_initializing_msg, "Should not have logged 'Initializing grammar contributions...' when debug is false")
        assert.is_false(found_registered_msg, "Should not have logged 'Grammar contributions registered.' when debug is false")
      end)
    end)
  end)
end)
