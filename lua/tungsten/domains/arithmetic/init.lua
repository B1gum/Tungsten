local M = {}
local registry = require("tungsten.core.registry")
local config = require("tungsten.config")     -- Added config
local logger = require "tungsten.util.logger" -- Added logger

-- Import the actual lpeg rule patterns from the 'rules' subdirectory
local tokens_mod = require "tungsten.core.tokenizer" -- Renamed to avoid conflict
local Fraction_rule = require "tungsten.domains.arithmetic.rules.fraction" -- Renamed
local Sqrt_rule = require "tungsten.domains.arithmetic.rules.sqrt"         -- Renamed
local SS_rules_mod = require "tungsten.domains.arithmetic.rules.supersub"   -- Renamed
local MulDiv_rule = require "tungsten.domains.arithmetic.rules.muldiv"     -- Renamed
local AddSub_rule = require "tungsten.domains.arithmetic.rules.addsub"     -- Renamed

function M.init_grammar()
    if config.debug then
      logger.notify("Arithmetic Domain: Initializing grammar contributions...", logger.levels.DEBUG, { title = "Tungsten Debug" })
    end

    registry.register_grammar_contribution("arithmetic", "Number", tokens_mod.number, "AtomBaseItem")
    registry.register_grammar_contribution("arithmetic", "Variable", tokens_mod.variable, "AtomBaseItem")
    registry.register_grammar_contribution("arithmetic", "Greek", tokens_mod.Greek, "AtomBaseItem")
    registry.register_grammar_contribution("arithmetic", "Fraction", Fraction_rule, "AtomBaseItem")
    registry.register_grammar_contribution("arithmetic", "Sqrt", Sqrt_rule, "AtomBaseItem")

    registry.register_grammar_contribution("arithmetic", "SupSub", SS_rules_mod.SupSub, "SupSub")
    registry.register_grammar_contribution("arithmetic", "Unary", SS_rules_mod.Unary, "Unary")
    registry.register_grammar_contribution("arithmetic", "MulDiv", MulDiv_rule, "MulDiv")
    registry.register_grammar_contribution("arithmetic", "AddSub", AddSub_rule, "AddSub")

    if config.debug then
      logger.notify("Arithmetic Domain: Grammar contributions registered.", logger.levels.DEBUG, { title = "Tungsten Debug" })
    end
end

M.init_grammar()
return M
