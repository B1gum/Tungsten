local error_handler = require("tungsten.util.error_handler")

local M = {}

function M.analyze_sequence(ast, opts, analyze)
	local nodes = ast.nodes or {}
	if #nodes == 0 then
		for _, n in ipairs(ast) do
			table.insert(nodes, n)
		end
	end
	local series = {}
	local dim, form

	local i = 1
	while i <= #nodes do
		local node = nodes[i]
		local t = node.type
		local treat_as_points = (t == "Point2" or t == "point_2d" or t == "Point3" or t == "point_3d")
			and not (opts.mode == "advanced" and (opts.form == "parametric" or opts.form == "polar"))
		if treat_as_points then
			local points = { node }
			local pdim = (t == "Point3" or t == "point_3d") and 3 or 2
			i = i + 1
			while i <= #nodes do
				local nxt = nodes[i]
				local nt = nxt.type
				local is_same = (pdim == 2 and (nt == "Point2" or nt == "point_2d"))
					or (pdim == 3 and (nt == "Point3" or nt == "point_3d"))
				if not is_same then
					break
				end
				table.insert(points, nxt)
				i = i + 1
			end

			if dim and dim ~= pdim then
				return nil,
					{
						code = error_handler.E_UNSUPPORTED_DIM,
						message = "Select expressions of the same dimension before plotting.",
					}
			end
			if form and form ~= "explicit" then
				return nil,
					{
						code = error_handler.E_MIXED_COORD_SYS,
						message = "Use the same coordinate system for all expressions before plotting.",
					}
			end
			dim = pdim
			form = "explicit"
			table.insert(series, { kind = "points", points = points })
		else
			local sub, err = analyze(node, opts)
			if not sub then
				return nil, err
			end
			if dim and dim ~= sub.dim then
				return nil,
					{
						code = error_handler.E_UNSUPPORTED_DIM,
						message = "Select expressions of the same dimension before plotting.",
					}
			end
			if form and form ~= sub.form then
				return nil,
					{
						code = error_handler.E_MIXED_COORD_SYS,
						message = "Use the same coordinate system for all expressions before plotting.",
					}
			else
				form = sub.form
			end
			dim = sub.dim
			for _, s in ipairs(sub.series) do
				table.insert(series, s)
			end
			i = i + 1
		end
	end

	return { dim = dim, form = form, series = series }
end

return M
