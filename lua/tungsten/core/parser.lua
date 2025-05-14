-- core/parser.lua
-- Parses input strings based on grammar into an AST
-----------------------------------------------------
local lpeg     = require "lpeg"
local registry = require "tungsten.core.registry"
local space    = require("tungsten.core.tokenizer").space
local config   = require "tungsten.config"

local M = {}

local compiled_grammar

function M.get_grammar()
  if not compiled_grammar then
    local tokens = require "tungsten.core.tokenizer"
    compiled_grammar = registry.get_combined_grammar(tokens)
  end
  return compiled_grammar
end

function M.parse(input)
  local current_grammar = M.get_grammar()
  if not current_grammar then
    error("Tungsten: Grammar not available or failed to compile.")
    return nil
  end
  return lpeg.match(space * current_grammar * space * -1, input)
end

function M.reset_grammar()
  compiled_grammar = nil
end

return M
