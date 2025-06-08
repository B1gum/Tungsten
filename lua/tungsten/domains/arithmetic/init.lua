-- tungsten/lua/tungsten/domains/arithmetic/init.lua
local lpeg = require "lpeg"
local P, V, C = lpeg.P, lpeg.V, lpeg.C
local tokens_mod = require "tungsten.core.tokenizer"
local ast_utils = require "tungsten.core.ast"
local registry = require "tungsten.core.registry"
local config = require "tungsten.config"
local logger = require "tungsten.util.logger"

local M = {}

M.metadata = {
  name = "arithmetic",
  priority = 100,
  dependencies = {},
  overrides = {},
  provides = {
    "EquationRule",
    "AtomBaseItem",
    "SupSub",
    "Unary",
    "MulDiv",
    "AddSub",
    "Fraction",
    "Sqrt",
    "SinFunction",
    "SolveSystemEquationsCapture",
  }
}


local standard_equation_pattern = (V("AddSub") * tokens_mod.space * tokens_mod.equals_op * tokens_mod.space * V("AddSub")) / function(lhs, _, rhs)
  return ast_utils.create_binary_operation_node("=", lhs, rhs)
end

function M.get_metadata()
  return M.metadata
end

function M.init_grammar()
    if config.debug then
      logger.notify("Arithmetic Domain: Initializing grammar contributions...", logger.levels.DEBUG, { title = "Tungsten Debug" })
    end

    local domain_name = M.metadata.name
    local domain_priority = M.metadata.priority

    local equation_rule_priority = domain_priority + 5
    local solve_system_priority = domain_priority + 10

    registry.register_grammar_contribution(domain_name, domain_priority, "Number", tokens_mod.number, "AtomBaseItem")
    registry.register_grammar_contribution(domain_name, domain_priority, "Variable", tokens_mod.variable, "AtomBaseItem")
    registry.register_grammar_contribution(domain_name, domain_priority, "Greek", tokens_mod.Greek, "AtomBaseItem")
    registry.register_grammar_contribution(domain_name, domain_priority, "Fraction", require("tungsten.domains.arithmetic.rules.fraction"), "AtomBaseItem")
    registry.register_grammar_contribution(domain_name, domain_priority, "Sqrt", require("tungsten.domains.arithmetic.rules.sqrt"), "AtomBaseItem")
    registry.register_grammar_contribution(domain_name, domain_priority, "SupSub", require("tungsten.domains.arithmetic.rules.supersub").SupSub, "SupSub")
    registry.register_grammar_contribution(domain_name, domain_priority, "Unary", require("tungsten.domains.arithmetic.rules.supersub").Unary, "Unary")
    registry.register_grammar_contribution(domain_name, domain_priority, "MulDiv", require("tungsten.domains.arithmetic.rules.muldiv"), "MulDiv")
    registry.register_grammar_contribution(domain_name, domain_priority, "AddSub", require("tungsten.domains.arithmetic.rules.addsub"), "AddSub")
    registry.register_grammar_contribution(domain_name, domain_priority, "SinFunction", require("tungsten.domains.arithmetic.rules.trig_functions").SinRule, "AtomBaseItem")
    registry.register_grammar_contribution(domain_name, equation_rule_priority, "EquationRule", equation_pattern_to_register, "TopLevelRule")
    registry.register_grammar_contribution(domain_name, solve_system_priority, "SolveSystemEquationsCapture", require "tungsten.domains.arithmetic.rules.solve_system_rule", "TopLevelRule")

    local equation_pattern_to_register
    if config.debug then
        if config.debug then
            logger.notify("Arithmetic Domain: Registering DEBUG EquationRule.", logger.levels.DEBUG, { title = "Tungsten Debug" })
        end
        equation_pattern_to_register = minimal_equation_debug_pattern
    else
        if config.debug then
            logger.notify("Arithmetic Domain: Registering STANDARD EquationRule.", logger.levels.DEBUG, { title = "Tungsten Debug" })
        end
        equation_pattern_to_register = standard_equation_pattern
    end
    registry.register_grammar_contribution(domain_name, domain_priority + 5, "EquationRule", equation_pattern_to_register, "TopLevelRule")


    if config.debug then
      logger.notify("Arithmetic Domain: Grammar contributions registered.", logger.levels.DEBUG, { title = "Tungsten Debug" })
    end
end

return M
