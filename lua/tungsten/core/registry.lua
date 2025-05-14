local lpeg_lib = require "lpeg" -- Renamed to avoid conflict if 'lpeg' is used as a local var name
local P, V = lpeg_lib.P, lpeg_lib.V
local tokens_mod = require "tungsten.core.tokenizer" -- Renamed to avoid conflict
local logger = require "tungsten.util.logger"
local config = require "tungsten.config"

local M = {
  domains = {},
  grammar_contributions = {},
  commands = {},
}

function M.register_domain(name, mod)
  M.domains[name] = mod
end

function M.register_grammar_contribution(domain, name_for_V_ref, pattern, category)
  table.insert(M.grammar_contributions, {
    domain = domain,
    name = name_for_V_ref,
    pattern = pattern,
    category = category or name_for_V_ref,
  })
end

function M.register_command(cmd_tbl)
  M.commands[#M.commands+1] = cmd_tbl
end

function M.get_combined_grammar()
  local grammar_def = {
    "Expression"
  }

  local atom_base_items = {}
  local primary_expression_rules = {}

  for _, contrib in ipairs(M.grammar_contributions) do
    if contrib.category == "AtomBaseItem" then
      table.insert(atom_base_items, contrib.pattern)
    elseif contrib.category == "PrimaryExpressionRule" then
      table.insert(primary_expression_rules, contrib.pattern)
    end

    if grammar_def[contrib.name] and contrib.pattern ~= grammar_def[contrib.name] then
      logger.notify(
        ("Registry: Grammar rule '%s' is being redefined or duplicated. Ensure this is intended."):format(contrib.name),
        logger.levels.WARN,
        { title = "Tungsten Registry" }
      )
    end
    grammar_def[contrib.name] = contrib.pattern
  end

  if #atom_base_items > 0 then
    local combined_atoms = atom_base_items[1]
    for i = 2, #atom_base_items do
      combined_atoms = combined_atoms + atom_base_items[i]
    end
    grammar_def.AtomBase = combined_atoms
                         + (tokens_mod.lbrace * V("Expression") * tokens_mod.rbrace)
                         + (tokens_mod.lparen * V("Expression") * tokens_mod.rparen)
                         + (tokens_mod.lbrack * V("Expression") * tokens_mod.rbrack)
  else
    logger.notify(
      "Registry: No 'AtomBaseItem' contributions. AtomBase will be empty (match nothing).",
      logger.levels.WARN,
      { title = "Tungsten Registry" }
    )
    grammar_def.AtomBase = P(false)
  end

  if grammar_def["AddSub"] then
    grammar_def.Expression = V("AddSub")
    for _, expr_rule_pattern in ipairs(primary_expression_rules) do
      if expr_rule_pattern ~= grammar_def["AddSub"] then
        grammar_def.Expression = grammar_def.Expression + expr_rule_pattern
      end
    end
  elseif #primary_expression_rules > 0 then
    logger.notify(
      "Registry: 'AddSub' not found for main Expression. Using other PrimaryExpressionRules.",
      logger.levels.WARN,
      { title = "Tungsten Registry" }
    )
    grammar_def.Expression = primary_expression_rules[1]
    for i = 2, #primary_expression_rules do
      grammar_def.Expression = grammar_def.Expression + primary_expression_rules[i]
    end
  else
    logger.notify(
      "Registry: No rule found to define 'Expression' (e.g., 'AddSub' or a PrimaryExpressionRule). Falling back to AtomBase.",
      logger.levels.ERROR, -- This is more severe, might lead to parser failure
      { title = "Tungsten Registry" }
    )
    grammar_def.Expression = V("AtomBase")
  end

  if config.debug then
    local keys = {}
    for k, _ in pairs(grammar_def) do table.insert(keys, k) end
    table.sort(keys)
    local key_list_str = table.concat(keys, ", ")
    logger.notify(
      "Registry: Final grammar definition keys: " .. key_list_str,
      logger.levels.DEBUG,
      { title = "Tungsten Debug" }
    )
  end

  local ok, compiled_grammar = pcall(lpeg_lib.P, grammar_def)
  if not ok then
    logger.notify(
      "Registry: Failed to compile combined grammar! Error: " .. tostring(compiled_grammar), -- compiled_grammar here is the error message
      logger.levels.ERROR,
      { title = "Tungsten Registry Error" }
    )
    return nil
  end

  return compiled_grammar
end

return M
