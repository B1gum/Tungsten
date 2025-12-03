local M = {
	name = "units",
	priority = 90,
}

M.grammar = { contributions = {} }
local c = M.grammar.contributions

local qty_rule = require("tungsten.domains.units.rules.qty")
local ang_rule = require("tungsten.domains.units.rules.ang")
local num_rule = require("tungsten.domains.units.rules.num")

c[#c + 1] = { name = "QtyCommand", pattern = qty_rule, category = "AtomBaseItem" }
c[#c + 1] = { name = "AngCommand", pattern = ang_rule, category = "AtomBaseItem" }
c[#c + 1] = { name = "NumCommand", pattern = num_rule, category = "AtomBaseItem" }

return M
