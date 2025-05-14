-- core/parser.lua
-- Parses input strings based on grammar into an AST
-----------------------------------------------------

local lpeg     = require "lpeg"
local registry = require "tungsten.core.registry"
local space    = require("tungsten.core.tokenizer").space
local config   = require "tungsten.config" -- Keep if used, otherwise remove
local logger = require "tungsten.util.logger" -- Added for logging

local M = {}

local compiled_grammar -- This will store the result of get_combined_grammar

function M.get_grammar()
  if not compiled_grammar then
    if config.debug then
      logger.notify("Parser: Compiling combined grammar...", logger.levels.DEBUG, {title = "Tungsten Parser"})
    end
    -- No need to pass tokens here anymore if get_combined_grammar doesn't expect it
    compiled_grammar = registry.get_combined_grammar()
    if not compiled_grammar then
        logger.notify("Parser: Grammar compilation failed. Subsequent parsing will fail.", logger.levels.ERROR, {title = "Tungsten Parser Error"})
        -- Fallback to a dummy grammar to prevent errors if lpeg.match is called with nil
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
  -- The check for nil current_grammar is implicitly handled by get_grammar now returning a dummy if compilation fails
  return lpeg.match(space * current_grammar * space * -1, input)
end

function M.reset_grammar()
  logger.notify("Parser: Resetting compiled grammar.", logger.levels.INFO, {title = "Tungsten Parser"})
  compiled_grammar = nil
end

return M
