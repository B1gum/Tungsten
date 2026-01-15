-- tungsten/lua/tungsten/core/registry.lua

local lpeg = require("lpeglabel")
local P, V = lpeg.P, lpeg.V
local tokens_mod = require("tungsten.core.tokenizer")
local logger = require("tungsten.util.logger")

local M = {
	domains_metadata = {},
	grammar_contributions = {},
	commands = {},
	handlers = {},
}

function M.reset()
	M.domains_metadata = {}
	M.grammar_contributions = {}
	M.commands = {}
	M.handlers = {}
end

function M.register_domain_metadata(name, metadata)
	if M.domains_metadata[name] then
		logger.warn("Tungsten Registry", ("Registry: Domain metadata for '%s' is being re-registered."):format(name))
	end
	M.domains_metadata[name] = metadata
	logger.debug(
		"Tungsten Debug",
		("Registry: Registered metadata for domain '%s' with priority %s."):format(name, tostring(metadata.priority))
	)
end

function M.get_domain_priority(domain_name)
	if M.domains_metadata[domain_name] and M.domains_metadata[domain_name].priority then
		return M.domains_metadata[domain_name].priority
	end
	logger.warn(
		"Tungsten Registry",
		("Registry: Priority not found for domain '%s', defaulting to 0."):format(domain_name)
	)
	return 0
end

function M.set_domain_priority(domain_name, priority)
	if not M.domains_metadata[domain_name] then
		M.domains_metadata[domain_name] = {}
	end
	M.domains_metadata[domain_name].priority = priority

	for _, contrib in ipairs(M.grammar_contributions) do
		if contrib.domain_name == domain_name then
			contrib.domain_priority = priority
		end
	end
	logger.debug("Tungsten Debug", ("Registry: Domain '%s' priority set to %s."):format(domain_name, tostring(priority)))
end

function M.register_grammar_contribution(domain_name, domain_priority, rule_name, pattern, category)
	table.insert(M.grammar_contributions, {
		domain_name = domain_name,
		domain_priority = domain_priority,
		name = rule_name,
		pattern = pattern,
		category = category or rule_name,
	})
	logger.debug(
		"Tungsten Debug",
		("Registry: Grammar contribution '%s' (%s) from domain '%s' (priority %d)"):format(
			rule_name,
			category,
			domain_name,
			domain_priority
		)
	)
end

function M.register_command(cmd_tbl)
	M.commands[#M.commands + 1] = cmd_tbl
end

local function copy_contributions(contributions)
	local out = {}
	for i, c in ipairs(contributions or {}) do
		out[i] = c
	end
	return out
end

function M.sort_contributions(contributions)
	local sorted = copy_contributions(contributions)
	table.sort(sorted, function(a, b)
		if a.category ~= b.category then
			return a.category < b.category
		end
		if a.domain_priority ~= b.domain_priority then
			return a.domain_priority > b.domain_priority
		end
		return a.name < b.name
	end)

	logger.debug("Tungsten Debug", "Registry: Sorted Grammar Contributions:")
	for i, contrib in ipairs(sorted) do
		logger.debug(
			"Tungsten Debug",
			("%d. %s (%s) from %s (Prio: %d)"):format(
				i,
				contrib.name,
				contrib.category,
				contrib.domain_name,
				contrib.domain_priority
			)
		)
	end

	return sorted
end

function M.build_atom_base(sorted)
	local grammar_def = { "Expression" }
	local rule_providers = {}
	local atom_base_item_patterns = {}
	local top_level_rule_names = {}

	if #sorted == 0 then
		logger.error("Tungsten Registry Error", "Registry: No grammar contributions. Parser will be empty.")
		grammar_def.AtomBase = P(false)
		grammar_def._top_level_rule_names = top_level_rule_names
		grammar_def._empty = true
		return grammar_def
	end

	for _, contrib in ipairs(sorted) do
		if contrib.category == "AtomBaseItem" then
			table.insert(atom_base_item_patterns, contrib.pattern)
			logger.debug(
				"Tungsten Debug",
				("Registry: Adding AtomBaseItem pattern for '%s' from %s."):format(contrib.name, contrib.domain_name)
			)
		else
			if grammar_def[contrib.name] and rule_providers[contrib.name] then
				local existing_provider = rule_providers[contrib.name]
				if existing_provider.domain_priority < contrib.domain_priority then
					logger.debug(
						"Tungsten Registry",
						("Registry: Rule '%s': %s (Prio %d) overrides %s (Prio %d)."):format(
							contrib.name,
							contrib.domain_name,
							contrib.domain_priority,
							existing_provider.domain_name,
							existing_provider.domain_priority
						)
					)
					grammar_def[contrib.name] = contrib.pattern
					rule_providers[contrib.name] =
						{ domain_name = contrib.domain_name, domain_priority = contrib.domain_priority }
				elseif
					existing_provider.domain_priority == contrib.domain_priority
					and existing_provider.domain_name ~= contrib.domain_name
				then
					logger.warn(
						"Tungsten Registry Conflict",
						("Registry: Rule '%s': CONFLICT/AMBIGUITY - %s (Prio %d) and %s (Prio %d) have same priority. '%s' takes precedence due to sort order."):format(
							contrib.name,
							contrib.domain_name,
							contrib.domain_priority,
							existing_provider.domain_name,
							existing_provider.domain_priority,
							contrib.domain_name
						)
					)
					grammar_def[contrib.name] = contrib.pattern
					rule_providers[contrib.name] =
						{ domain_name = contrib.domain_name, domain_priority = contrib.domain_priority }
				else
					logger.debug(
						"Tungsten Registry",
						("Registry: Rule '%s': %s (Prio %d) NOT overriding existing from %s (Prio %d)."):format(
							contrib.name,
							contrib.domain_name,
							contrib.domain_priority,
							existing_provider.domain_name,
							existing_provider.domain_priority
						)
					)
				end
			else
				grammar_def[contrib.name] = contrib.pattern
				rule_providers[contrib.name] = { domain_name = contrib.domain_name, domain_priority = contrib.domain_priority }
			end

			if contrib.category == "TopLevelRule" and grammar_def[contrib.name] == contrib.pattern then
				table.insert(top_level_rule_names, contrib.name)
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
		logger.warn(
			"Tungsten Registry",
			"Registry: No 'AtomBaseItem' contributions. AtomBase will only be parenthesized expressions."
		)
		grammar_def.AtomBase = (tokens_mod.lbrace * V("Expression") * tokens_mod.rbrace)
			+ (tokens_mod.lparen * V("Expression") * tokens_mod.rparen)
			+ (tokens_mod.lbrack * V("Expression") * tokens_mod.rbrack)
			+ P(false)
	end

	grammar_def._top_level_rule_names = top_level_rule_names
	return grammar_def
end

function M.choose_expression_content(atom_def, _opts)
	local content_rule_priority = { "AddSub", "MulDiv", "Convolution", "Unary", "SupSub", "AtomBase" }
	local expressions = {}
	if atom_def._empty then
		expressions.ExpressionContent = P(false)
		expressions.Expression = P(false)
		return expressions
	end
	local expression_content_defined = false
	local addsub_is_defined = atom_def["AddSub"] ~= nil
	local chosen_content_rule_name = ""

	for _, rule_name in ipairs(content_rule_priority) do
		if atom_def[rule_name] then
			expressions.ExpressionContent = V(rule_name)
			chosen_content_rule_name = rule_name
			logger.debug("Tungsten Debug", "Registry: ExpressionContent is V('" .. rule_name .. "').")
			expression_content_defined = true
			break
		end
	end

	if not addsub_is_defined and expression_content_defined then
		logger.warn(
			"Tungsten Registry",
			"Registry: Main expression rule 'AddSub' not found. Attempting to find a fallback. This may lead to parsing issues."
		)
		if chosen_content_rule_name == "AtomBase" then
			logger.error(
				"Tungsten Registry Error",
				"Registry: No suitable rule found for 'ExpressionContent' other than AtomBase. Parser may be limited."
			)
		elseif chosen_content_rule_name ~= "" and chosen_content_rule_name ~= "AddSub" then
			logger.warn(
				"Tungsten Registry",
				"Registry: Using '" .. chosen_content_rule_name .. "' as a fallback for 'ExpressionContent'."
			)
		end
	end

	if not expression_content_defined then
		logger.error(
			"Tungsten Registry Error",
			"Registry: CRITICAL - Cannot define 'ExpressionContent' as core rules are missing. Defaulting to P(false)."
		)
		expressions.ExpressionContent = P(false)
	end

	local expression_choices = {}
	for _, name in ipairs(atom_def._top_level_rule_names or {}) do
		table.insert(expression_choices, V(name))
	end
	table.insert(expression_choices, V("ExpressionContent"))

	if #expression_choices == 0 then
		expressions.Expression = P(false)
		logger.error(
			"Tungsten Registry Error",
			"Registry: CRITICAL - No rule choices for 'Expression'. Defaulting to P(false)."
		)
	else
		local final_expression_pattern = expression_choices[1]
		for i = 2, #expression_choices do
			final_expression_pattern = final_expression_pattern + expression_choices[i]
		end
		expressions.Expression = final_expression_pattern
	end

	return expressions
end

function M.compile_grammar(atoms, expressions)
	local grammar_def = { "Expression" }
	for k, v in pairs(atoms or {}) do
		if k ~= "_top_level_rule_names" and k ~= "_empty" then
			grammar_def[k] = v
		end
	end
	for k, v in pairs(expressions or {}) do
		grammar_def[k] = v
	end

	do
		local keys = {}
		for k, _ in pairs(grammar_def) do
			table.insert(keys, tostring(k))
		end
		table.sort(keys)
		logger.debug("Tungsten Debug", "Registry: Final grammar definition keys: " .. table.concat(keys, ", "))
	end

	local ok, compiled_grammar_or_err = pcall(lpeg.P, grammar_def)
	if not ok then
		logger.error(
			"Tungsten Registry Error",
			"Registry: Error compiling final grammar table: " .. tostring(compiled_grammar_or_err)
		)
		return nil
	end

	logger.debug("Tungsten Debug", "Registry: Combined grammar compiled successfully.")

	return compiled_grammar_or_err
end

function M.get_combined_grammar(contributions, opts)
	contributions = contributions or M.grammar_contributions
	local sorted = M.sort_contributions(contributions)
	local atom_base = M.build_atom_base(sorted)
	local exprs = M.choose_expression_content(atom_base, opts)
	return M.compile_grammar(atom_base, exprs)
end

function M.reset_handlers()
	M.handlers = {}
end

function M.register_handler(node_type, handler_fn)
	M.handlers[node_type] = handler_fn
end

function M.register_handlers(handler_map)
	for node_type, fn in pairs(handler_map or {}) do
		M.handlers[node_type] = fn
	end
end

function M.get_handlers()
	return M.handlers
end

return M
