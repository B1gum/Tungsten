-- lua/tungsten/domains/calculus/init.lua
-- Calculus domain for Tungsten plugin

local M = {}
local logger = require "tungsten.util.logger"
local registry = require "tungsten.core.registry"
local LimitRule = require "tungsten.domains.calculus.rules.limit"
local IntegralRule = require "tungsten.domains.calculus.rules.integral"
local OrdinaryDerivativeRule = require "tungsten.domains.calculus.rules.ordinary_derivatives"
local PartialDerivativeRule = require "tungsten.domains.calculus.rules.partial_derivatives"
local SumRule = require "tungsten.domains.calculus.rules.sum"

M.metadata = {
  name = "calculus",
  priority = 150,
  dependencies = {"arithmetic"},
  overrides = {},
  provides = {
    "Limit",
    "Integral",
    "OrdinaryDerivative",
    "PartialDerivative",
    "Summation",
  }
}

function M.get_metadata()
  return M.metadata
end

function M.init_grammar()
  logger.debug("Tungsten Debug", "Calculus Domain: Initializing grammar contributions...")

  local domain_name = M.metadata.name
  local domain_priority = M.metadata.priority

  registry.register_grammar_contribution(domain_name, domain_priority, "Limit", LimitRule, "AtomBaseItem")
  registry.register_grammar_contribution(domain_name, domain_priority, "Integral", IntegralRule, "AtomBaseItem")
  registry.register_grammar_contribution(domain_name, domain_priority, "OrdinaryDerivative", OrdinaryDerivativeRule, "AtomBaseItem")
  registry.register_grammar_contribution(domain_name, domain_priority, "PartialDerivative", PartialDerivativeRule, "AtomBaseItem")
  registry.register_grammar_contribution(domain_name, domain_priority, "Summation", SumRule, "AtomBaseItem")

  logger.debug("Tungsten Debug", "Calculus Domain: Grammar contributions registered for: " .. table.concat(M.metadata.provides, ", "))
end

return M
