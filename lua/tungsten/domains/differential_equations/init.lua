-- lua/tungsten/domains/differential_equations/init.lua
-- Differential Equations domain for Tungsten plugin

local M = {}
local config = require "tungsten.config"
local logger = require "tungsten.util.logger"
local registry = require "tungsten.core.registry"
local ODERule = require "tungsten.domains.differential_equations.rules.ode"
local ODESystemRule = require "tungsten.domains.differential_equations.rules.ode_system"
local WronskianRule = require "tungsten.domains.differential_equations.rules.wronskian"
local LaplaceRule = require "tungsten.domains.differential_equations.rules.laplace"
local ConvolutionRule = require "tungsten.domains.differential_equations.rules.convolution"


M.metadata = {
  name = "differential_equations",
  priority = 140,
  dependencies = { "arithmetic", "calculus" },
  overrides = {},
  provides = {
    "ODE",
    "ODESystem",
    "Wronskian",
    "LaplaceTransform",
    "Convolution",
    "EvaluatedDerivative",
  },
}

function M.get_metadata()
  return M.metadata
end

function M.init_grammar()
  require "tungsten.domains.differential_equations.commands"

  if config.debug then
    logger.notify("Differential Equations Domain: Initializing grammar contributions...", logger.levels.DEBUG, { title = "Tungsten Debug" })
  end

  local domain_name = M.metadata.name
  local domain_priority = M.metadata.priority

  registry.register_grammar_contribution(domain_name, domain_priority, "ODE", ODERule, "TopLevelRule")
  registry.register_grammar_contribution(domain_name, domain_priority, "ODESystem", ODESystemRule, "TopLevelRule")
  registry.register_grammar_contribution(domain_name, domain_priority, "Wronskian", WronskianRule, "AtomBaseItem")
  registry.register_grammar_contribution(domain_name, domain_priority, "LaplaceTransform", LaplaceRule, "AtomBaseItem")
  registry.register_grammar_contribution(domain_name, domain_priority, "Convolution", ConvolutionRule, "Convolution")
  registry.register_grammar_contribution(domain_name, domain_priority, "EvaluatedDerivative", EvaluatedDerivativeRule, "AtomBaseItem")

  if config.debug then
    logger.notify("Differential Equations Domain: Grammar contributions registered.", logger.levels.DEBUG, { title = "Tungsten Debug" })
  end
end


return M

