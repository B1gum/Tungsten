-- lua/tungsten/domains/differential_equations/init.lua
-- Differential Equations domain for Tungsten plugin

local ODERule = require 'tungsten.domains.differential_equations.rules.ode'
local ODESystemRule = require 'tungsten.domains.differential_equations.rules.ode_system'
local WronskianRule = require 'tungsten.domains.differential_equations.rules.wronskian'
local LaplaceRule = require 'tungsten.domains.differential_equations.rules.laplace'
local ConvolutionRule = require 'tungsten.domains.differential_equations.rules.convolution'

local M = {
  name = 'differential_equations',
  priority = 140,
  dependencies = { "arithmetic", "calculus" },
  overrides = {},
}

M.grammar = { contributions = {}, extensions = {} }
local c = M.grammar.contributions
local prio = M.priority
c[#c+1] = { name = 'ODE', pattern = ODERule, category = 'TopLevelRule', priority = prio }
c[#c+1] = { name = 'ODESystem', pattern = ODESystemRule, category = 'TopLevelRule', priority = prio }
c[#c+1] = { name = 'Wronskian', pattern = WronskianRule, category = 'AtomBaseItem', priority = prio }
c[#c+1] = { name = 'LaplaceTransform', pattern = LaplaceRule, category = 'AtomBaseItem', priority = prio }
c[#c+1] = { name = 'Convolution', pattern = ConvolutionRule, category = 'Convolution', priority = prio }

do
  local cmds = require 'tungsten.domains.differential_equations.commands'
  M.commands = cmds.commands
end

function M.handlers()
  require 'tungsten.domains.differential_equations.wolfram_handlers'
end

return M
