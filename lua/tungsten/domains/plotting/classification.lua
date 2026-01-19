local M = {}
local functions = require("tungsten.domains.plotting.classification.functions")
local points = require("tungsten.domains.plotting.classification.points")
local sequences = require("tungsten.domains.plotting.classification.sequences")

local handlers = {}

local function register(aliases, handler)
	for _, alias in ipairs(aliases) do
		handlers[alias] = handler
	end
end

register({ "Sequence", "sequence" }, function(ast, opts)
	return sequences.analyze_sequence(ast, opts, M.analyze)
end)
register({ "equality", "Equality" }, function(ast, opts)
	return functions.analyze_equality(ast, opts)
end)
register({ "Parametric2D", "parametric_2d" }, function(ast)
	return functions.analyze_parametric2d(ast)
end)
register({ "Parametric3D", "parametric_3d" }, function(ast)
	return functions.analyze_parametric3d(ast)
end)
register({ "Polar2D", "polar_2d" }, function(ast)
	return functions.analyze_polar2d(ast)
end)
register({ "inequality", "Inequality" }, function(ast)
	return functions.analyze_inequality(ast)
end)
register({ "Point2", "point_2d" }, function(ast, opts)
	return points.analyze_point2(ast, opts)
end)
register({ "Point3", "point_3d" }, function(ast, opts)
	return points.analyze_point3(ast, opts)
end)

function M.analyze(ast, opts)
	opts = opts or {}
	local handler = handlers[ast.type]
	if handler then
		return handler(ast, opts)
	end

	return functions.analyze_expression(ast, opts)
end

return M
