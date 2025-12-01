local M = {
	name = "units",
	priority = 100,
	dependencies = { "arithmetic" },
}

M.grammar = { contributions = {} }

local si_rules = require("tungsten.domains.units.rules.siunitx")
local c = M.grammar.contributions

local prio = 100

c[#c + 1] = { name = "SI_Qty", pattern = si_rules.Qty, category = "AtomBaseItem", priority = prio }
c[#c + 1] = { name = "SI_Ang", pattern = si_rules.Ang, category = "AtomBaseItem", priority = prio }
c[#c + 1] = { name = "SI_Num", pattern = si_rules.Num, category = "AtomBaseItem", priority = prio }

return M
