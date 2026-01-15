-- lua/tungsten/backends/wolfram/domains/units.lua
local M = {}

M.handlers = {}

local units_util = require("tungsten.domains.units.util")

M.handlers.quantity = function(node, render_fn)
	local val = render_fn(node.value)
	local unit_str = units_util.render_unit(node.unit)

	return string.format('Quantity[%s, "%s"]', val, unit_str)
end

M.handlers.angle = function(node, render_fn)
	return string.format('Quantity[%s, "AngularDegrees"]', render_fn(node.value))
end

M.handlers.num_cmd = function(node, render_fn)
	return render_fn(node.value)
end

return M
