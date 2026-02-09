-- tungsten/lua/tungsten/domains/arithmetic/init.lua
local tokens_mod = require("tungsten.core.tokenizer")

local M = {
	name = "arithmetic",
	priority = 100,
	dependencies = {},
	overrides = {},
}

M.grammar = { contributions = {}, extensions = {} }

local prio = M.priority
local supersub = require("tungsten.domains.arithmetic.rules.supersub")
local log_functions = require("tungsten.domains.arithmetic.rules.log_functions")

local relation_rules = require("tungsten.domains.arithmetic.rules.relation")

local c = M.grammar.contributions
c[#c + 1] = { name = "Number", pattern = tokens_mod.number, category = "AtomBaseItem", priority = prio }
c[#c + 1] = { name = "Variable", pattern = tokens_mod.variable, category = "AtomBaseItem", priority = prio }
c[#c + 1] = { name = "Greek", pattern = tokens_mod.Greek, category = "AtomBaseItem", priority = prio }
c[#c + 1] = {
	name = "InfinitySymbol",
	pattern = tokens_mod.infinity_symbol,
	category = "AtomBaseItem",
	priority = prio,
}
c[#c + 1] = {
	name = "Fraction",
	pattern = require("tungsten.domains.arithmetic.rules.fraction"),
	category = "AtomBaseItem",
	priority = prio,
}
c[#c + 1] = {
	name = "Binomial",
	pattern = require("tungsten.domains.arithmetic.rules.binomial"),
	category = "AtomBaseItem",
	priority = prio,
}
c[#c + 1] = {
	name = "Sqrt",
	pattern = require("tungsten.domains.arithmetic.rules.sqrt"),
	category = "AtomBaseItem",
	priority = prio,
}
c[#c + 1] = {
	name = "FunctionCall",
	pattern = require("tungsten.domains.arithmetic.rules.function_call"),
	category = "AtomBaseItem",
	priority = prio,
}
c[#c + 1] = { name = "LnFunction", pattern = log_functions.LnRule, category = "AtomBaseItem", priority = prio }
c[#c + 1] = { name = "LogFunction", pattern = log_functions.LogRule, category = "AtomBaseItem", priority = prio }
c[#c + 1] = { name = "SupSub", pattern = supersub.SupSub, category = "SupSub", priority = prio }
c[#c + 1] = { name = "Unary", pattern = supersub.Unary, category = "Unary", priority = prio }
c[#c + 1] = {
	name = "MulDiv",
	pattern = require("tungsten.domains.arithmetic.rules.muldiv"),
	category = "MulDiv",
	priority = prio,
}
c[#c + 1] = {
	name = "AddSub",
	pattern = require("tungsten.domains.arithmetic.rules.addsub"),
	category = "AddSub",
	priority = prio,
}
c[#c + 1] = {
	name = "SinFunction",
	pattern = require("tungsten.domains.arithmetic.rules.trig_functions").SinRule,
	category = "AtomBaseItem",
	priority = prio,
}
c[#c + 1] = {
	name = "CosFunction",
	pattern = require("tungsten.domains.arithmetic.rules.trig_functions").CosRule,
	category = "AtomBaseItem",
	priority = prio,
}
c[#c + 1] = {
	name = "TanFunction",
	pattern = require("tungsten.domains.arithmetic.rules.trig_functions").TanRule,
	category = "AtomBaseItem",
	priority = prio,
}
c[#c + 1] = { name = "Equality", pattern = relation_rules.Equality, category = "TopLevelRule", priority = prio + 5 }
c[#c + 1] = { name = "Inequality", pattern = relation_rules.Inequality, category = "TopLevelRule", priority = prio + 5 }
c[#c + 1] = {
	name = "SolveSystemEquationsCapture",
	pattern = require("tungsten.domains.arithmetic.rules.solve_system_rule"),
	category = "TopLevelRule",
	priority = prio + 10,
}

return M
