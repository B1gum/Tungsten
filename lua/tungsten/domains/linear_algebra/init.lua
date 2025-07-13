-- lua/tungsten/domains/linear_algebra/init.lua

local tokenizer = require 'tungsten.core.tokenizer'
local MatrixRule = require 'tungsten.domains.linear_algebra.rules.matrix'
local VectorRule = require 'tungsten.domains.linear_algebra.rules.vector'
local DeterminantRule = require 'tungsten.domains.linear_algebra.rules.determinant'
local NormRule = require 'tungsten.domains.linear_algebra.rules.norm'
local RankRule = require 'tungsten.domains.linear_algebra.rules.rank'

local M = {
  name = 'linear_algebra',
  priority = 120,
  dependencies = {"arithmetic"},
  overrides = {},
}

M.grammar = { contributions = {}, extensions = {} }
local c = M.grammar.contributions
local prio = M.priority
c[#c+1] = { name = 'Matrix', pattern = MatrixRule, category = 'Matrix', priority = prio }
c[#c+1] = { name = 'Vector', pattern = VectorRule, category = 'AtomBaseItem', priority = prio }
c[#c+1] = { name = 'Determinant', pattern = DeterminantRule, category = 'AtomBaseItem', priority = prio }
c[#c+1] = { name = 'Norm', pattern = NormRule, category = 'AtomBaseItem', priority = prio }
c[#c+1] = { name = 'IntercalCommand', pattern = tokenizer.intercal_command, category = 'AtomBaseItem', priority = prio }
c[#c+1] = { name = 'Rank', pattern = RankRule, category = 'AtomBaseItem', priority = prio }

do
  local cmds = require 'tungsten.domains.linear_algebra.commands'
  M.commands = cmds.commands
end

function M.handlers()
  require 'tungsten.backends.wolfram.domains.linear_algebra'
end

return M
