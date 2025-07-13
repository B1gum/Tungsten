-- tungsten/lua/tungsten/domains/arithmetic/init.lua
local lpeg = require "lpeglabel"
local V = lpeg.V
local tokens_mod = require 'tungsten.core.tokenizer'
local ast_utils = require 'tungsten.core.ast'

local M = {
  name = 'arithmetic',
  priority = 100,
  dependencies = {},
  overrides = {},
}

M.grammar = { contributions = {}, extensions = {} }

local prio = M.priority
local supersub = require('tungsten.domains.arithmetic.rules.supersub')
local standard_equation_pattern = (V('AddSub') * tokens_mod.space * tokens_mod.equals_op * tokens_mod.space * V('AddSub')) / function(lhs, _, rhs)
  return ast_utils.create_binary_operation_node('=', lhs, rhs)
end

local c = M.grammar.contributions
c[#c+1] = { name = 'Number', pattern = tokens_mod.number, category = 'AtomBaseItem', priority = prio }
c[#c+1] = { name = 'Variable', pattern = tokens_mod.variable, category = 'AtomBaseItem', priority = prio }
c[#c+1] = { name = 'Greek', pattern = tokens_mod.Greek, category = 'AtomBaseItem', priority = prio }
c[#c+1] = { name = 'Fraction', pattern = require('tungsten.domains.arithmetic.rules.fraction'), category = 'AtomBaseItem', priority = prio }
c[#c+1] = { name = 'Sqrt', pattern = require('tungsten.domains.arithmetic.rules.sqrt'), category = 'AtomBaseItem', priority = prio }
c[#c+1] = { name = 'FunctionCall', pattern = require('tungsten.domains.arithmetic.rules.function_call'), category = 'AtomBaseItem', priority = prio }
c[#c+1] = { name = 'SupSub', pattern = supersub.SupSub, category = 'SupSub', priority = prio }
c[#c+1] = { name = 'Unary', pattern = supersub.Unary, category = 'Unary', priority = prio }
c[#c+1] = { name = 'MulDiv', pattern = require('tungsten.domains.arithmetic.rules.muldiv'), category = 'MulDiv', priority = prio }
c[#c+1] = { name = 'AddSub', pattern = require('tungsten.domains.arithmetic.rules.addsub'), category = 'AddSub', priority = prio }
c[#c+1] = { name = 'SinFunction', pattern = require('tungsten.domains.arithmetic.rules.trig_functions').SinRule, category = 'AtomBaseItem', priority = prio }
c[#c+1] = { name = 'EquationRule', pattern = standard_equation_pattern, category = 'TopLevelRule', priority = prio + 5 }
c[#c+1] = { name = 'SolveSystemEquationsCapture', pattern = require('tungsten.domains.arithmetic.rules.solve_system_rule'), category = 'TopLevelRule', priority = prio + 10 }

function M.handlers()
  require('tungsten.backends.wolfram.domains.arithmetic')
end

return M
