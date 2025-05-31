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
      if a.category == "TopLevelRule" and b.category ~= "TopLevelRule" then return true end
      if b.category == "TopLevelRule" and a.category ~= "TopLevelRule" then return false end
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
    logger.notify(
        "Registry: No grammar contributions at all. 'Expression' will default to AtomBase.",
        logger.levels.ERROR, { title = "Tungsten Registry Error" }
    )
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
          logger.notify(
            ("Registry: Rule '%s': %s (Prio %d) overrides %s (Prio %d)."):format(
              contrib.name, contrib.domain_name, contrib.domain_priority,
              existing_provider.domain_name, existing_provider.domain_priority),
            logger.levels.DEBUG, { title = "Tungsten Registry" }
          )
          grammar_def[contrib.name] = contrib.pattern
          rule_providers[contrib.name] = { domain_name = contrib.domain_name, domain_priority = contrib.domain_priority }
        elseif existing_provider.domain_priority == contrib.domain_priority and existing_provider.domain_name ~= contrib.domain_name then
           logger.notify(
            ("Registry: Rule '%s': CONFLICT/AMBIGUITY - %s (Prio %d) and %s (Prio %d) have same priority. '%s' takes precedence due to sort order."):format(
              contrib.name, contrib.domain_name, contrib.domain_priority,
              existing_provider.domain_name, existing_provider.domain_priority, contrib.domain_name
            ), logger.levels.WARN, { title = "Tungsten Registry Conflict" }
          )
          grammar_def[contrib.name] = contrib.pattern
          rule_providers[contrib.name] = { domain_name = contrib.domain_name, domain_priority = contrib.domain_priority }
        else
             logger.notify(
            ("Registry: Rule '%s': %s (Prio %d) NOT overriding %s (Prio %d)."):format(
              contrib.name, contrib.domain_name, contrib.domain_priority,
              existing_provider.domain_name, existing_provider.domain_priority),
            logger.levels.DEBUG, { title = "Tungsten Registry" }
          )
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
    grammar_def.AtomBase = combined_atom_base
                         + (tokens_mod.lbrace * V("Expression") * tokens_mod.rbrace)
                         + (tokens_mod.lparen * V("Expression") * tokens_mod.rparen)
                         + (tokens_mod.lbrack * V("Expression") * tokens_mod.rbrack)
  else
    logger.notify("Registry: No 'AtomBaseItem' contributions. AtomBase will be empty.", logger.levels.WARN, { title = "Tungsten Registry" })
    grammar_def.AtomBase = P(false)
  end

  local actual_expression_content_pattern
  local addsub_found = grammar_def.AddSub ~= nil

  if addsub_found then
    actual_expression_content_pattern = V("AddSub")
    if config.debug then
      logger.notify("Registry: ExpressionContent is V('AddSub').", logger.levels.DEBUG, { title = "Tungsten Debug" })
    end
  else
    logger.notify("Registry: Main expression rule 'AddSub' not found. Attempting to find a fallback. This may lead to parsing issues.", logger.levels.WARN, { title = "Tungsten Registry" })
    if grammar_def.MulDiv then
      actual_expression_content_pattern = V("MulDiv")
      if config.debug then
        logger.notify("Registry: ExpressionContent is V('MulDiv') (fallback from AddSub).", logger.levels.DEBUG, { title = "Tungsten Debug" })
      end
      logger.notify("Registry: Using 'MulDiv' as a fallback for 'Expression'.", logger.levels.WARN, { title = "Tungsten Registry" })
    elseif grammar_def.AtomBase and grammar_def.AtomBase ~= P(false) then
       actual_expression_content_pattern = V("AtomBase")
       if config.debug then
          logger.notify("Registry: ExpressionContent is V('AtomBase') (further fallback from AddSub/MulDiv).", logger.levels.DEBUG, { title = "Tungsten Debug" })
       end
       logger.notify("Registry: Using 'AtomBase' as a fallback for 'Expression'.", logger.levels.WARN, { title = "Tungsten Registry" })
       logger.notify("Registry: No suitable rule found for 'Expression'. Parser will likely fail.", logger.levels.ERROR, { title = "Tungsten Registry Error" })
    else
      actual_expression_content_pattern = P(false)
      logger.notify("Registry: CRITICAL - Cannot define 'ExpressionContent' as AddSub, MulDiv, or AtomBase are missing. Defaulting to P(false).", logger.levels.ERROR, { title = "Tungsten Registry Error" })
      logger.notify("Registry: No suitable rule found for 'Expression'. Parser will likely fail.", logger.levels.ERROR, { title = "Tungsten Registry Error" })
    end
  end
  grammar_def.ExpressionContent = actual_expression_content_pattern

  if grammar_def.EquationRule then
    grammar_def.Expression = V("EquationRule") + actual_expression_content_pattern
    if config.debug then
        logger.notify("Registry: Main 'Expression' rule is V('EquationRule') + resolved ExpressionContent pattern.", logger.levels.DEBUG, {title="Tungsten Debug"})
    end
  else
    grammar_def.Expression = actual_expression_content_pattern
    if config.debug then
        logger.notify("Registry: Main 'Expression' rule is resolved ExpressionContent pattern (EquationRule missing).", logger.levels.DEBUG, {title="Tungsten Debug"})
    end
  end

  if config.debug then
    local keys = {}
    for k, _ in pairs(grammar_def) do
      table.insert(keys, tostring(k))
    end
    table.sort(keys)
    local key_list_str = table.concat(keys, ", ")
    logger.notify("Registry: Final grammar definition keys: " .. key_list_str, logger.levels.DEBUG, { title = "Tungsten Debug" })
  end

  if config.debug then
    if grammar_def.EquationRule then
      logger.notify("Registry: DEBUG - EquationRule IS PRESENT in grammar_def.", logger.levels.DEBUG, {title="Tungsten Debug"})
      logger.notify("Registry: DEBUG - Type of grammar_def.EquationRule: " .. type(grammar_def.EquationRule), logger.levels.DEBUG, {title="Tungsten Debug"})
      if type(grammar_def.EquationRule) == "function" then
        logger.notify("Registry: DEBUG - grammar_def.EquationRule IS a function. Attempting to call it...", logger.levels.DEBUG, {title="Tungsten Debug"})
        local p_ok, pattern_or_error = pcall(grammar_def.EquationRule)
        if p_ok then
          logger.notify("Registry: DEBUG - EquationRule function call successful. Returned type: " .. type(pattern_or_error), logger.levels.DEBUG, {title="Tungsten Debug"})
          if type(pattern_or_error) == "table" and getmetatable(pattern_or_error) and getmetatable(pattern_or_error).__name == "pattern" then
            logger.notify("Registry: DEBUG - EquationRule function returned a valid LPeg pattern.", logger.levels.DEBUG, {title="Tungsten Debug"})
          else
            logger.notify("Registry: DEBUG - EquationRule function DID NOT return a recognizable LPeg pattern. Returned: " .. tostring(pattern_or_error), logger.levels.DEBUG, {title="Tungsten Debug"})
          end
        else
          logger.notify("Registry: DEBUG - EquationRule function call FAILED. Error: " .. tostring(pattern_or_error), logger.levels.DEBUG, {title="Tungsten Debug"})
        end
      end
    else
      logger.notify("Registry: DEBUG - EquationRule IS NIL/MISSING in grammar_def!", logger.levels.DEBUG, {title="Tungsten Debug"})
    end

    if grammar_def.AddSub then
      logger.notify("Registry: DEBUG - AddSub IS PRESENT. Type: " .. type(grammar_def.AddSub), logger.levels.DEBUG, {title="Tungsten Debug"})
    else
      logger.notify("Registry: DEBUG - AddSub IS NIL/MISSING in grammar_def!", logger.levels.DEBUG, {title="Tungsten Debug"})
    end
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
