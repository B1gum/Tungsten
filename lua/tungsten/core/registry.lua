local lpeg_lib = require "lpeg"
local P, V = lpeg_lib.P, lpeg_lib.V
local tokens_mod = require "tungsten.core.tokenizer"
local logger = require "tungsten.util.logger"
local config = require "tungsten.config"

local M = {
  domains_metadata = {}, -- Stores metadata for each registered domain {name = metadata_table}
  grammar_contributions = {}, -- Stores individual grammar rule contributions
  commands = {},
}

-- Stores the fully resolved metadata for a domain
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
  return 0 -- Default priority if not found
end

-- Keeps track of grammar rules provided by domains
function M.register_grammar_contribution(domain_name, domain_priority, name_for_V_ref, pattern, category)
  table.insert(M.grammar_contributions, {
    domain_name = domain_name,
    domain_priority = domain_priority, -- Store priority with the contribution
    name = name_for_V_ref, -- This is the key for lpeg's V reference (e.g., "Number", "AddSub")
    pattern = pattern,
    category = category or name_for_V_ref, -- e.g., "AtomBaseItem", "SupSub"
  })
  if config.debug then
      logger.notify(("Registry: Grammar contribution '%s' (%s) from domain '%s' (priority %d)"):format(name_for_V_ref, category, domain_name, domain_priority), logger.levels.DEBUG, { title = "Tungsten Debug"})
  end
end

function M.register_command(cmd_tbl)
  M.commands[#M.commands+1] = cmd_tbl
end

function M.get_combined_grammar()
  local grammar_def = { "Expression" } -- Initial grammar table for lpeg.P
  local rule_providers = {} -- Tracks { domain_name, domain_priority } for each defined rule key

  -- 1. Sort all grammar contributions
  -- Primary sort: Category (to group similar items, though lpeg handles order of +)
  -- Secondary sort: Domain priority (descending, higher priority first)
  -- Tertiary sort: Rule name (for deterministic behavior within same priority)
  table.sort(M.grammar_contributions, function(a, b)
    if a.category ~= b.category then
      return a.category < b.category
    end
    if a.domain_priority ~= b.domain_priority then
      return a.domain_priority > b.domain_priority -- Higher priority first
    end
    return a.name < b.name
  end)

  if config.debug then
    logger.notify("Registry: Sorted Grammar Contributions:", logger.levels.DEBUG, { title = "Tungsten Debug" })
    for i, contrib in ipairs(M.grammar_contributions) do
        logger.notify(("%d. %s (%s) from %s (Prio: %d)"):format(i, contrib.name, contrib.category, contrib.domain_name, contrib.domain_priority), logger.levels.DEBUG, {title = "Tungsten Debug"})
    end
  end

  -- 2. Populate grammar_def, respecting priorities for named rules
  --    LPeg's ordered choice (op1 + op2) tries op1 first.
  --    If we want higher priority rules to be tried first when they are part of a sum (like AtomBaseItem),
  --    they should appear earlier in the sum.
  --    For direct rule definitions (grammar_def.RuleName = pattern), the last one set by highest priority wins.

  local atom_base_item_patterns = {}
  -- Other categorized patterns can be built similarly if needed
  -- e.g. local primary_expression_rule_patterns = {}

  for _, contrib in ipairs(M.grammar_contributions) do
    -- Handle categorized rules that are combined using ordered choice (+)
    if contrib.category == "AtomBaseItem" then
      -- Since they are sorted by priority (higher first), adding them in this order
      -- to an LPeg sum (p1 + p2 + ...) means higher priority patterns are tried first.
      table.insert(atom_base_item_patterns, contrib.pattern)
      if config.debug then
          logger.notify(("Registry: Adding AtomBaseItem pattern for '%s' from %s."):format(contrib.name, contrib.domain_name), logger.levels.DEBUG, {title="Tungsten Debug"})
      end
    else
      -- Handle named rules (e.g., "SupSub", "AddSub", "Expression")
      -- If a rule with this name is already defined, the current one (higher priority due to sorting)
      -- will overwrite it. This is the desired behavior for definitive rules.
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
              existing_provider.domain_name, existing_provider.domain_priority, contrib.domain_name -- Or the one that came first in sort if stable
            ), logger.levels.WARN, { title = "Tungsten Registry Conflict" }
          )
          -- Allow overwrite based on secondary sort criteria (rule name, or simply the one processed last)
          grammar_def[contrib.name] = contrib.pattern
          rule_providers[contrib.name] = { domain_name = contrib.domain_name, domain_priority = contrib.domain_priority }
        else
            -- Do not overwrite if new rule has lower priority
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

  -- 3. Combine AtomBaseItem patterns using ordered choice
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
    grammar_def.AtomBase = P(false) -- Match nothing
  end

  -- 4. Define the main 'Expression' rule
  -- This assumes that a rule named 'AddSub' (or your chosen top-level expression rule)
  -- has been contributed by a domain and is now in grammar_def.
  if grammar_def.AddSub then
    grammar_def.Expression = V("AddSub")
    -- If you have other primary expression rules that should also be alternatives at the top level:
    -- for _, contrib in ipairs(M.grammar_contributions) do
    --   if contrib.category == "PrimaryExpressionRule" and contrib.name ~= "AddSub" then
    --     grammar_def.Expression = grammar_def.Expression + V(contrib.name)
    --   end
    -- end
  elseif #M.grammar_contributions > 0 then
    logger.notify("Registry: Main expression rule 'AddSub' not found. Attempting to find a fallback. This may lead to parsing issues.", logger.levels.WARN, { title = "Tungsten Registry" })
    -- Fallback: try to use the highest priority registered rule as Expression if AddSub is missing. This is risky.
    -- Or, simply ensure a domain (e.g. arithmetic) always provides 'AddSub' or a designated 'Expression' rule.
    -- For now, let's assume 'AddSub' (or a similar top-level rule) MUST be defined.
    local top_rule_candidate = nil
    for rule_name, _ in pairs(grammar_def) do
        if rule_name ~= "Expression" and rule_name ~= "AtomBase" and type(grammar_def[rule_name]) == "table" then -- lpeg patterns are tables
            top_rule_candidate = rule_name -- very naive pick
            break
        end
    end
    if top_rule_candidate then
        logger.notify("Registry: Using '"..top_rule_candidate.."' as a fallback for 'Expression'.", logger.levels.WARN, { title = "Tungsten Registry" })
        grammar_def.Expression = V(top_rule_candidate)
    else
        logger.notify("Registry: No suitable rule found for 'Expression'. Parser will likely fail.", logger.levels.ERROR, { title = "Tungsten Registry Error" })
        grammar_def.Expression = V("AtomBase") -- Last resort
    end

  else
    logger.notify("Registry: No grammar contributions at all. 'Expression' will default to AtomBase.", logger.levels.ERROR, { title = "Tungsten Registry Error" })
    grammar_def.Expression = V("AtomBase")
  end

  if config.debug then
    local keys = {}
    for k, _ in pairs(grammar_def) do table.insert(keys, k) end
    table.sort(keys)
    local key_list_str = table.concat(keys, ", ")
    logger.notify("Registry: Final grammar definition keys: " .. key_list_str, logger.levels.DEBUG, { title = "Tungsten Debug" })
    -- You could also print the structure of grammar_def if needed for deep debugging
  end

  -- Compile the grammar
  local ok, compiled_grammar_or_err = pcall(lpeg_lib.P, grammar_def)
  if not ok then
    logger.notify("Registry: Failed to compile combined grammar! Error: " .. tostring(compiled_grammar_or_err), logger.levels.ERROR, { title = "Tungsten Registry Error" })
    return nil -- Return nil on failure
  end

  if config.debug then
    logger.notify("Registry: Combined grammar compiled successfully.", logger.levels.DEBUG, { title = "Tungsten Debug" })
  end

  return compiled_grammar_or_err
end

return M
