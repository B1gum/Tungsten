local M = {}
local registry = require("tungsten.core.registry")
local config = require("tungsten.config")
local logger = require "tungsten.util.logger"

-- Import rule patterns
local tokens_mod = require "tungsten.core.tokenizer"
local Fraction_rule = require "tungsten.domains.arithmetic.rules.fraction"
local Sqrt_rule = require "tungsten.domains.arithmetic.rules.sqrt"
local SS_rules_mod = require "tungsten.domains.arithmetic.rules.supersub"
local MulDiv_rule = require "tungsten.domains.arithmetic.rules.muldiv"
local AddSub_rule = require "tungsten.domains.arithmetic.rules.addsub"

-- Domain Metadata
M.metadata = {
  name = "arithmetic",
  priority = 100, -- Base priority for arithmetic rules
  dependencies = {},
  overrides = {}, -- e.g., { rule_name = "other_domain.SomeRule", with = "MyRule" }
  provides = { "AtomBaseItem", "SupSub", "Unary", "MulDiv", "AddSub" }
}

function M.get_metadata()
  return M.metadata
end

function M.init_grammar()
    if config.debug then
      logger.notify("Arithmetic Domain: Initializing grammar contributions...", logger.levels.DEBUG, { title = "Tungsten Debug" })
    end

    -- Pass domain name and priority when registering
    local domain_name = M.metadata.name
    local domain_priority = M.metadata.priority

    registry.register_grammar_contribution(domain_name, domain_priority, "Number", tokens_mod.number, "AtomBaseItem")
    registry.register_grammar_contribution(domain_name, domain_priority, "Variable", tokens_mod.variable, "AtomBaseItem")
    registry.register_grammar_contribution(domain_name, domain_priority, "Greek", tokens_mod.Greek, "AtomBaseItem")
    registry.register_grammar_contribution(domain_name, domain_priority, "Fraction", Fraction_rule, "AtomBaseItem")
    registry.register_grammar_contribution(domain_name, domain_priority, "Sqrt", Sqrt_rule, "AtomBaseItem")

    registry.register_grammar_contribution(domain_name, domain_priority, "SupSub", SS_rules_mod.SupSub, "SupSub") -- This rule is a key building block
    registry.register_grammar_contribution(domain_name, domain_priority, "Unary", SS_rules_mod.Unary, "Unary") -- Built upon SupSub
    registry.register_grammar_contribution(domain_name, domain_priority, "MulDiv", MulDiv_rule, "MulDiv") -- Built upon Unary
    registry.register_grammar_contribution(domain_name, domain_priority, "AddSub", AddSub_rule, "AddSub") -- Top-level for arithmetic expressions

    if config.debug then
      logger.notify("Arithmetic Domain: Grammar contributions registered.", logger.levels.DEBUG, { title = "Tungsten Debug" })
    end
end

return M
