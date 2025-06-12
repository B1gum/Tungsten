-- lua/tungsten/domains/linear_algebra/init.lua
local M = {}
local config = require "tungsten.config"
local logger = require "tungsten.util.logger"
local registry = require "tungsten.core.registry"
local tokenizer = require "tungsten.core.tokenizer"

local MatrixRule = require "tungsten.domains.linear_algebra.rules.matrix"
local VectorRule = require "tungsten.domains.linear_algebra.rules.vector"
local DeterminantRule = require "tungsten.domains.linear_algebra.rules.determinant"
local NormRule = require "tungsten.domains.linear_algebra.rules.norm"
local RankRule = require "tungsten.domains.linear_algebra.rules.rank"

require("tungsten.domains.linear_algebra.commands")
require("tungsten.domains.linear_algebra.wolfram_handlers")

M.metadata = {
  name = "linear_algebra",
  priority = 120,
  dependencies = {"arithmetic"},
  overrides = {},
  provides = {
    "Matrix",
    "Vector",
    "Determinant",
    "Norm",
    "LinearIndependentTest",
    "Rank",
  }
}

function M.get_metadata()
  return M.metadata
end

function M.init_grammar()
  if config.debug then
    logger.notify("Linear Algebra Domain: Initializing grammar contributions...", logger.levels.DEBUG, { title = "Tungsten Debug" })
  end

  local domain_name = M.metadata.name
  local domain_priority = M.metadata.priority

  registry.register_grammar_contribution(domain_name, domain_priority, "Matrix", MatrixRule, "Matrix")
  registry.register_grammar_contribution(domain_name, domain_priority, "Vector", VectorRule, "AtomBaseItem")
  registry.register_grammar_contribution(domain_name, domain_priority, "Determinant", DeterminantRule, "AtomBaseItem")
  registry.register_grammar_contribution(domain_name, domain_priority, "Norm", NormRule, "AtomBaseItem")
  registry.register_grammar_contribution(domain_name, domain_priority, "IntercalCommand", tokenizer.intercal_command, "AtomBaseItem")
  registry.register_grammar_contribution(domain_name, domain_priority, "Rank", RankRule, "AtomBaseItem")

  if config.debug then
    logger.notify("Linear Algebra Domain: Grammar contributions registered for: " .. table.concat(M.metadata.provides, ", "), logger.levels.DEBUG, { title = "Tungsten Debug" })
  end
end

return M

