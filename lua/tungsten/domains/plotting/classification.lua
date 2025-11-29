local M = {}
local functions = require("tungsten.domains.plotting.classification.functions")
local points = require("tungsten.domains.plotting.classification.points")
local sequences = require("tungsten.domains.plotting.classification.sequences")

function M.analyze(ast, opts)
	opts = opts or {}
	local t = ast.type
	if t == "Sequence" or t == "sequence" then
		return sequences.analyze_sequence(ast, opts, M.analyze)
	elseif t == "equality" or t == "Equality" then
		return functions.analyze_equality(ast, opts)
	elseif t == "Parametric2D" or t == "parametric_2d" then
		return functions.analyze_parametric2d(ast)
	elseif t == "Parametric3D" or t == "parametric_3d" then
		return functions.analyze_parametric3d(ast)
	elseif t == "Polar2D" or t == "polar_2d" then
		return functions.analyze_polar2d(ast)
	elseif t == "inequality" or t == "Inequality" then
		return functions.analyze_inequality(ast)
	elseif t == "Point2" or t == "point_2d" then
		return points.analyze_point2(ast, opts)
	elseif t == "Point3" or t == "point_3d" then
		return points.analyze_point3(ast, opts)
	else
		return functions.analyze_expression(ast, opts)
	end
end

return M
