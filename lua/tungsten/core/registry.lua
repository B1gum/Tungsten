-- tungsten/lua/tungsten/core/registry.lua

local lpeg_lib = require "lpeg"
local P, V = lpeg_lib.P, lpeg_lib.V
local tokens_mod = require "tungsten.core.tokenizer"
local logger = require "tungsten.util.logger"
local config = require "tungsten.config"

local M = {
  domains_metadata = {},
  grammar_contributions = {},
  commands = {},
}

function M.register_domain_metadata(name, metadata)
  if M.domains_metadata[name] then
    logger.notify(
      ("Registry: Domain metadata for '%s' is being re-registered."):format(name),
      logger.levels.WARN, { title = "Tungsten Registry" }
    )
  end
  M.domains_metadata[name] = metadata
  if config.debug then
    logger.notify(("Registry: Registered metadata for domain '%s' with priority %s."):format(name, tostring(metadata.priority)), logger.levels.DEBUG, { title = "Tungsten Debug" })
  end
end

function M.get_domain_priority(domain_name)
  if M.domains_metadata[domain_name] and M.domains_metadata[domain_name].priority then
    return M.domains_metadata[domain_name].priority
  end
  logger.notify(("Registry: Priority not found for domain '%s', defaulting to 0."):format(domain_name), logger.levels.WARN, { title = "Tungsten Registry" })
  return 0
end

function M.register_grammar_contribution(domain_name, domain_priority, rule_name, pattern, category)
  table.insert(M.grammar_contributions, {
    domain_name = domain_name,
    domain_priority = domain_priority,
    name = rule_name,
    pattern = pattern,
    category = category or rule_name,
  })
  if config.debug then
      logger.notify(("Registry: Grammar contribution '%s' (%s) from domain '%s' (priority %d)"):format(rule_name, category, domain_name, domain_priority), logger.levels.DEBUG, { title = "Tungsten Debug"})
  end
end

function M.register_command(cmd_tbl)
  M.commands[#M.commands+1] = cmd_tbl
end

function M.get_combined_grammar()
  local grammar_def = { "Expression" }
  local rule_providers = {}

  table.sort(M.grammar_contributions, function(a, b)
    if a.category ~= b.category then
      return a.category < b.category
    end
    if a.domain_priority ~= b.domain_priority then
      return a.domain_priority > b.domain_priority
    end
    return a.name < b.name
  end)

  if config.debug then
    logger.notify("Registry: Sorted Grammar Contributions:", logger.levels.DEBUG, { title = "Tungsten Debug" })
    for i, contrib in ipairs(M.grammar_contributions) do
        logger.notify(("%d. %s (%s) from %s (Prio: %d)"):format(i, contrib.name, contrib.category, contrib.domain_name, contrib.domain_priority), logger.levels.DEBUG, {title = "Tungsten Debug"})
    end
  end

  if #M.grammar_contributions == 0 then
    logger.notify("Registry: No grammar contributions. Parser will be empty.", logger.levels.ERROR, { title = "Tungsten Registry Error" })
    grammar_def.AtomBase = P(false)
    grammar_def.ExpressionContent = P(false)
    grammar_def.Expression = P(false)
    return lpeg_lib.P(grammar_def)
  end

  local atom_base_item_patterns = {}

  for _, contrib in ipairs(M.grammar_contributions) do
    if contrib.category == "AtomBaseItem" then
      table.insert(atom_base_item_patterns, contrib.pattern)
      if config.debug then
          logger.notify(("Registry: Adding AtomBaseItem pattern for '%s' from %s."):format(contrib.name, contrib.domain_name), logger.levels.DEBUG, {title="Tungsten Debug"})
      end
    else 
      if grammar_def[contrib.name] and rule_providers[contrib.name] then
        local existing_provider = rule_providers[contrib.name]
        if existing_provider.domain_priority < contrib.domain_priority then
          if config.debug then logger.notify(("Registry: Rule '%s': %s (Prio %d) overrides %s (Prio %d)."):format(contrib.name, contrib.domain_name, contrib.domain_priority, existing_provider.domain_name, existing_provider.domain_priority), logger.levels.DEBUG, { title = "Tungsten Registry" }) end
          grammar_def[contrib.name] = contrib.pattern
          rule_providers[contrib.name] = { domain_name = contrib.domain_name, domain_priority = contrib.domain_priority }
        elseif existing_provider.domain_priority == contrib.domain_priority and existing_provider.domain_name ~= contrib.domain_name then
           if config.debug then logger.notify(("Registry: Rule '%s': CONFLICT/AMBIGUITY - %s (Prio %d) and %s (Prio %d) have same priority. '%s' takes precedence due to sort order."):format(contrib.name, contrib.domain_name, contrib.domain_priority, existing_provider.domain_name, existing_provider.domain_priority, contrib.domain_name), logger.levels.WARN, { title = "Tungsten Registry Conflict" }) end
           grammar_def[contrib.name] = contrib.pattern
           rule_providers[contrib.name] = { domain_name = contrib.domain_name, domain_priority = contrib.domain_priority }
        else
            if config.debug then logger.notify(("Registry: Rule '%s': %s (Prio %d) NOT overriding existing from %s (Prio %d)."):format(contrib.name, contrib.domain_name, contrib.domain_priority, existing_provider.domain_name, existing_provider.domain_priority), logger.levels.DEBUG, { title = "Tungsten Registry" }) end
        end
      else
        grammar_def[contrib.name] = contrib.pattern
        rule_providers[contrib.name] = { domain_name = contrib.domain_name, domain_priority = contrib.domain_priority }
      end
    end
  end

  if #atom_base_item_patterns > 0 then
    local combined_atom_base = atom_base_item_patterns[1]
    for i = 2, #atom_base_item_patterns do
      combined_atom_base = combined_atom_base + atom_base_item_patterns[i]
    end
    grammar_def.AtomBase = combined_atom_base +
                         (tokens_mod.lbrace * V("Expression") * tokens_mod.rbrace) +
                         (tokens_mod.lparen * V("Expression") * tokens_mod.rparen) +
                         (tokens_mod.lbrack * V("Expression") * tokens_mod.rbrack)
  else
    logger.notify("Registry: No 'AtomBaseItem' contributions. AtomBase will only be parenthesized expressions.", logger.levels.WARN, { title = "Tungsten Registry" })
    grammar_def.AtomBase = (tokens_mod.lbrace * V("Expression") * tokens_mod.rbrace) +
                         (tokens_mod.lparen * V("Expression") * tokens_mod.rparen) +
                         (tokens_mod.lbrack * V("Expression") * tokens_mod.rbrack) +
                         P(false)
  end

  local content_rule_priority = {"AddSub", "MulDiv", "Convolution", "Unary", "SupSub", "AtomBase"}
  local expression_content_defined = false
  local addsub_is_defined = grammar_def["AddSub"] ~= nil
  local chosen_content_rule_name = ""

  for _, rule_name in ipairs(content_rule_priority) do
    if grammar_def[rule_name] then
      grammar_def.ExpressionContent = V(rule_name)
      chosen_content_rule_name = rule_name
      if config.debug then logger.notify("Registry: ExpressionContent is V('" .. rule_name .. "').", logger.levels.DEBUG, { title = "Tungsten Debug" }) end
      expression_content_defined = true
      break
    end
  end

  if not addsub_is_defined and expression_content_defined then -- Only if AddSub was NOT defined by any domain
    logger.notify("Registry: Main expression rule 'AddSub' not found. Attempting to find a fallback. This may lead to parsing issues.", logger.levels.WARN, { title = "Tungsten Registry" })
    if chosen_content_rule_name == "AtomBase" then
        logger.notify("Registry: No suitable rule found for 'ExpressionContent' other than AtomBase. Parser may be limited.", logger.levels.ERROR, { title = "Tungsten Registry Error" })
    elseif chosen_content_rule_name ~= "" and chosen_content_rule_name ~= "AddSub" then 
        logger.notify("Registry: Using '" .. chosen_content_rule_name .. "' as a fallback for 'ExpressionContent'.", logger.levels.WARN, { title = "Tungsten Registry" })
    end
  end

  if not expression_content_defined then
    logger.notify("Registry: CRITICAL - Cannot define 'ExpressionContent' as core rules are missing. Defaulting to P(false).", logger.levels.ERROR, { title = "Tungsten Registry Error" })
    grammar_def.ExpressionContent = P(false)
  end


  local expression_choices = {}
  for _, contrib in ipairs(M.grammar_contributions) do
    if contrib.category == "TopLevelRule" then
      if grammar_def[contrib.name] == contrib.pattern then
        table.insert(expression_choices, V(contrib.name))
      end
    end
  end

  table.insert(expression_choices, V("ExpressionContent"))

  if #expression_choices == 0 then
    grammar_def.Expression = P(false)
    logger.notify("Registry: CRITICAL - No rule choices for 'Expression'. Defaulting to P(false).", logger.levels.ERROR, { title = "Tungsten Registry Error"})
  else
    local final_expression_pattern = expression_choices[1]
    for i = 2, #expression_choices do
      final_expression_pattern = final_expression_pattern + expression_choices[i]
    end
    grammar_def.Expression = final_expression_pattern
  end

  if config.debug then
    local keys = {}
    for k, _ in pairs(grammar_def) do table.insert(keys, tostring(k)) end
    table.sort(keys)
    logger.notify("Registry: Final grammar definition keys: " .. table.concat(keys, ", "), logger.levels.DEBUG, { title = "Tungsten Debug" })
  end

  local ok, compiled_grammar_or_err = pcall(lpeg_lib.P, grammar_def)
  if not ok then
    logger.notify("Registry: Error compiling final grammar table: " .. tostring(compiled_grammar_or_err), logger.levels.ERROR, { title = "Tungsten Registry Error" })
    return nil
  end

  if config.debug then
    logger.notify("Registry: Combined grammar compiled successfully.", logger.levels.DEBUG, { title = "Tungsten Debug" })
  end

  return compiled_grammar_or_err
end

return M

