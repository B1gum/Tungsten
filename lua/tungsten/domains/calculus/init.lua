-- lua/tungsten/domains/calculus/init.lua
-- Calculus domain for Tungsten plugin

local LimitRule = require("tungsten.domains.calculus.rules.limit")
local IntegralRule = require("tungsten.domains.calculus.rules.integral")
local OrdinaryDerivativeRule = require("tungsten.domains.calculus.rules.ordinary_derivatives")
local PartialDerivativeRule = require("tungsten.domains.calculus.rules.partial_derivatives")
local SumRule = require("tungsten.domains.calculus.rules.sum")

local M = {
	name = "calculus",
	priority = 150,
	dependencies = { "arithmetic" },
	overrides = {},
}

M.grammar = { contributions = {}, extensions = {} }
local c = M.grammar.contributions
local prio = M.priority
c[#c + 1] = { name = "Limit", pattern = LimitRule, category = "AtomBaseItem", priority = prio }
c[#c + 1] = { name = "Integral", pattern = IntegralRule, category = "AtomBaseItem", priority = prio }
c[#c + 1] =
	{ name = "OrdinaryDerivative", pattern = OrdinaryDerivativeRule, category = "AtomBaseItem", priority = prio }
c[#c + 1] = { name = "PartialDerivative", pattern = PartialDerivativeRule, category = "AtomBaseItem", priority = prio }
c[#c + 1] = { name = "Summation", pattern = SumRule, category = "AtomBaseItem", priority = prio }

return M
