-- lua/tungsten/domains/arithmetic/init.lua
local M = {}
local registry = require "tungsten.core.registry"
local config = require "tungsten.config"
local logger = require "tungsten.util.logger"

local tokens_mod = require "tungsten.core.tokenizer"
local Fraction_rule = require "tungsten.domains.arithmetic.rules.fraction"
local Sqrt_rule = require "tungsten.domains.arithmetic.rules.sqrt"
local SS_rules_mod = require "tungsten.domains.arithmetic.rules.supersub"
local MulDiv_rule = require "tungsten.domains.arithmetic.rules.muldiv"
local AddSub_rule = require "tungsten.domains.arithmetic.rules.addsub"
local TrigFunctionRules = require("tungsten.domains.arithmetic.rules.trig_functions")


M.metadata = {
  name = "arithmetic",
  priority = 100,
  dependencies = {},
  overrides = {},
  provides = {
    "AtomBaseItem",
    "SupSub",
    "Unary",
    "MulDiv",
    "AddSub",
    "Fraction",
    "Sqrt",
    "SinFunction",
  }
}

function M.get_metadata()
  return M.metadata
end

function M.init_grammar()
    if config.debug then
      logger.notify("Arithmetic Domain: Initializing grammar contributions...", logger.levels.DEBUG, { title = "Tungsten Debug" })
    end

    local domain_name = M.metadata.name
    local domain_priority = M.metadata.priority

    registry.register_grammar_contribution(domain_name, domain_priority, "Number", tokens_mod.number, "AtomBaseItem")
    registry.register_grammar_contribution(domain_name, domain_priority, "Variable", tokens_mod.variable, "AtomBaseItem")
    registry.register_grammar_contribution(domain_name, domain_priority, "Greek", tokens_mod.Greek, "AtomBaseItem")
    registry.register_grammar_contribution(domain_name, domain_priority, "Fraction", Fraction_rule, "AtomBaseItem")
    registry.register_grammar_contribution(domain_name, domain_priority, "Sqrt", Sqrt_rule, "AtomBaseItem")

    registry.register_grammar_contribution(domain_name, domain_priority, "SupSub", SS_rules_mod.SupSub, "SupSub")
    registry.register_grammar_contribution(domain_name, domain_priority, "Unary", SS_rules_mod.Unary, "Unary")

    registry.register_grammar_contribution(domain_name, domain_priority, "MulDiv", MulDiv_rule, "MulDiv")
    registry.register_grammar_contribution(domain_name, domain_priority, "AddSub", AddSub_rule, "AddSub")

    registry.register_grammar_contribution(domain_name, domain_priority, "SinFunction", TrigFunctionRules.SinRule, "AtomBaseItem")

    if config.debug then
      logger.notify("Arithmetic Domain: Grammar contributions registered.", logger.levels.DEBUG, { title = "Tungsten Debug" })
    end
end

return M
