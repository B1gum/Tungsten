-- core/registry.lua
-- central registry for domains, rules, and commands
-------------------------------------------------------
local M = { domains = {}, rules = {}, commands = {} }

function M.register_domain(name, mod)
  M.domains[name] = mod
end

function M.register_rule(domain, rule_tbl)  -- rule_tbl = {id, precedence, parse, render}
  M.rules[#M.rules+1] = rule_tbl
end

function M.register_command(cmd_tbl)        -- cmd_tbl = {':TgFactor', run = fn}
  M.commands[#M.commands+1] = cmd_tbl
end

return M

