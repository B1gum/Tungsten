-- tests/unit/domains/arithmetic/init_spec.lua
-- Unit tests for the arithmetic domain initialization.
---------------------------------------------------------------------

package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path

local spy = require('luassert.spy')
local match = require('luassert.match')
local helpers = require('tests.helpers')
local mock_utils = helpers.mock_utils
local vim_test_env = helpers.vim_test_env

local mock_registry
local mock_config
local mock_logger
local mock_tokens_mod
local mock_fraction_rule
local mock_sqrt_rule
local mock_ss_rules_mod
local mock_muldiv_rule
local mock_addsub_rule
local arithmetic_domain

local mock_lpeg_pattern = function(name)
  return { __is_mock_lpeg_pattern = true, name = name or "mock_pattern" }
end

describe("Tungsten Arithmetic Domain: lua/tungsten/domains/arithmetic/init.lua", function()
  local modules_to_reset_before_each = {
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
  }

  before_each(function()
    vim_test_env.setup()

    mock_registry = mock_utils.mock_module('tungsten.core.registry', {
      register_grammar_contribution = spy.new(function() end)
    })

    mock_config = mock_utils.mock_module('tungsten.config', {
      debug = false
    })

    mock_logger = mock_utils.mock_module('tungsten.util.logger', {
      notify = spy.new(function() end),
      levels = { DEBUG = "DEBUG_LEVEL", INFO = "INFO_LEVEL" }
    })

    mock_tokens_mod = mock_utils.mock_module('tungsten.core.tokenizer', {
      number = mock_lpeg_pattern("tokens_mod.number"),
      variable = mock_lpeg_pattern("tokens_mod.variable"),
      Greek = mock_lpeg_pattern("tokens_mod.Greek")
    })

    mock_fraction_rule = mock_utils.mock_module('tungsten.domains.arithmetic.rules.fraction', mock_lpeg_pattern("Fraction_rule"))
    mock_sqrt_rule = mock_utils.mock_module('tungsten.domains.arithmetic.rules.sqrt', mock_lpeg_pattern("Sqrt_rule"))

    mock_ss_rules_mod = mock_utils.mock_module('tungsten.domains.arithmetic.rules.supersub', {
      SupSub = mock_lpeg_pattern("SS_rules_mod.SupSub"),
      Unary = mock_lpeg_pattern("SS_rules_mod.Unary")
    })

    mock_muldiv_rule = mock_utils.mock_module('tungsten.domains.arithmetic.rules.muldiv', mock_lpeg_pattern("MulDiv_rule"))
    mock_addsub_rule = mock_utils.mock_module('tungsten.domains.arithmetic.rules.addsub', mock_lpeg_pattern("AddSub_rule"))

    arithmetic_domain = require("tungsten.domains.arithmetic.init")
  end)

  after_each(function()
    vim_test_env.teardown()
    mock_utils.reset_modules(modules_to_reset_before_each)
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
      assert.are.same({ "AtomBaseItem", "SupSub", "Unary", "MulDiv", "AddSub", "SinFunction" }, metadata.provides)
    end)
  end)

  describe("init_grammar()", function()
    local expected_domain_name
    local expected_domain_priority

    before_each(function()
      expected_domain_name = "arithmetic"
      expected_domain_priority = 100
    end)

    it("should call registry.register_grammar_contribution for Number token", function()
      arithmetic_domain.init_grammar()
      assert.spy(mock_registry.register_grammar_contribution).was.called_with(
        expected_domain_name,
        expected_domain_priority,
        "Number",
        mock_tokens_mod.number,
        "AtomBaseItem"
      )
    end)

    it("should call registry.register_grammar_contribution for Variable token", function()
      arithmetic_domain.init_grammar()
      assert.spy(mock_registry.register_grammar_contribution).was.called_with(
        expected_domain_name,
        expected_domain_priority,
        "Variable",
        mock_tokens_mod.variable,
        "AtomBaseItem"
      )
    end)

    it("should call registry.register_grammar_contribution for Greek token", function()
      arithmetic_domain.init_grammar()
      assert.spy(mock_registry.register_grammar_contribution).was.called_with(
        expected_domain_name,
        expected_domain_priority,
        "Greek",
        mock_tokens_mod.Greek,
        "AtomBaseItem"
      )
    end)

    it("should call registry.register_grammar_contribution for Fraction rule", function()
      arithmetic_domain.init_grammar()
      assert.spy(mock_registry.register_grammar_contribution).was.called_with(
        expected_domain_name,
        expected_domain_priority,
        "Fraction",
        mock_fraction_rule,
        "AtomBaseItem"
      )
    end)

    it("should call registry.register_grammar_contribution for Sqrt rule", function()
      arithmetic_domain.init_grammar()
      assert.spy(mock_registry.register_grammar_contribution).was.called_with(
        expected_domain_name,
        expected_domain_priority,
        "Sqrt",
        mock_sqrt_rule,
        "AtomBaseItem"
      )
    end)

    it("should call registry.register_grammar_contribution for SupSub rule", function()
      arithmetic_domain.init_grammar()
      assert.spy(mock_registry.register_grammar_contribution).was.called_with(
        expected_domain_name,
        expected_domain_priority,
        "SupSub",
        mock_ss_rules_mod.SupSub,
        "SupSub"
      )
    end)

    it("should call registry.register_grammar_contribution for Unary rule", function()
      arithmetic_domain.init_grammar()
      assert.spy(mock_registry.register_grammar_contribution).was.called_with(
        expected_domain_name,
        expected_domain_priority,
        "Unary",
        mock_ss_rules_mod.Unary,
        "Unary"
      )
    end)

    it("should call registry.register_grammar_contribution for MulDiv rule", function()
      arithmetic_domain.init_grammar()
      assert.spy(mock_registry.register_grammar_contribution).was.called_with(
        expected_domain_name,
        expected_domain_priority,
        "MulDiv",
        mock_muldiv_rule,
        "MulDiv"
      )
    end)

    it("should call registry.register_grammar_contribution for AddSub rule", function()
      arithmetic_domain.init_grammar()
      assert.spy(mock_registry.register_grammar_contribution).was.called_with(
        expected_domain_name,
        expected_domain_priority,
        "AddSub",
        mock_addsub_rule,
        "AddSub"
      )
    end)

    it("should call registry.register_grammar_contribution the correct number of times", function()
      arithmetic_domain.init_grammar()
      assert.spy(mock_registry.register_grammar_contribution).was.called(10)
    end)

    describe("Debug Logging", function()
      it("should log 'Initializing grammar contributions...' if config.debug is true", function()
        mock_config.debug = true
        arithmetic_domain.init_grammar()
        assert.spy(mock_logger.notify).was.called_with(
          "Arithmetic Domain: Initializing grammar contributions...",
          mock_logger.levels.DEBUG,
          { title = "Tungsten Debug" }
        )
      end)

      it("should log 'Grammar contributions registered.' if config.debug is true", function()
        mock_config.debug = true
        arithmetic_domain.init_grammar()
        assert.spy(mock_logger.notify).was.called_with(
          "Arithmetic Domain: Grammar contributions registered.",
          mock_logger.levels.DEBUG,
          { title = "Tungsten Debug" }
        )
      end)

      it("should not log debug messages if config.debug is false", function()
        mock_config.debug = false
        arithmetic_domain.init_grammar()
        local notify_calls = mock_logger.notify.calls
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
