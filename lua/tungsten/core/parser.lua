-- core/parser.lua
-- Parses input strings based on grammar into an AST
-----------------------------------------------------

local lpeg     = require "lpeg"
local registry = require "tungsten.core.registry"
local space    = require "tungsten.core.tokenizer".space
local config   = require "tungsten.config"
local logger = require "tungsten.util.logger"

local M = {}

local compiled_grammar

function M.get_grammar()
  if not compiled_grammar then
    if config.debug then
      logger.notify("Parser: Compiling combined grammar...", logger.levels.DEBUG, {title = "Tungsten Parser"})
    end
    compiled_grammar = registry.get_combined_grammar()
    if not compiled_grammar then
        logger.notify("Parser: Grammar compilation failed. Subsequent parsing will fail.", logger.levels.ERROR, {title = "Tungsten Parser Error"})
        compiled_grammar = lpeg.P(false)
    else
      if config.debug then
        logger.notify("Parser: Combined grammar compiled and cached.", logger.levels.DEBUG, {title = "Tungsten Parser"})
      end
    end
  end
  return compiled_grammar
end

function M.parse(input)
  local current_grammar = M.get_grammar()
  return lpeg.match(space * current_grammar * space * -1, input)
end

function M.reset_grammar()
  logger.notify("Parser: Resetting compiled grammar.", logger.levels.INFO, {title = "Tungsten Parser"})
  compiled_grammar = nil
end

return M
