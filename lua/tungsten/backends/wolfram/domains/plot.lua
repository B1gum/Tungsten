-- lua/tungsten/backends/wolfram/domains/plot.lua
-- Wolfram Language renderers for plotting specific AST nodes

local M = {}

local function render_node(child, recur_render)
	local rendered = recur_render(child)
	if type(rendered) == "table" and rendered.error then
		return nil, rendered
	end
	return rendered, nil
end

local function render_node_list(nodes, recur_render)
	local rendered_nodes = {}
	for _, child in ipairs(nodes or {}) do
		local rendered, err = render_node(child, recur_render)
		if not rendered then
			return nil, err
		end
		rendered_nodes[#rendered_nodes + 1] = rendered
	end
	return rendered_nodes, nil
end

local function render_point(coords, recur_render)
	local rendered, err = render_node_list(coords, recur_render)
	if not rendered then
		return err
	end
	return string.format("Point[{%s}]", table.concat(rendered, ", "))
end

local function render_parametric(coords, recur_render)
	local rendered, err = render_node_list(coords, recur_render)
	if not rendered then
		return err
	end
	return string.format("{%s}", table.concat(rendered, ", "))
end

local function normalize_sequence_nodes(node)
	if type(node.nodes) == "table" then
		return node.nodes
	end
	local collected = {}
	local i = 1
	while node[i] ~= nil do
		collected[#collected + 1] = node[i]
		i = i + 1
	end
	return collected
end

local inequality_ops = {
	["≤"] = "<=",
	["≥"] = ">=",
}

M.handlers = {
	Sequence = function(node, recur_render)
		local nodes = normalize_sequence_nodes(node)
		local rendered, err = render_node_list(nodes, recur_render)
		if not rendered then
			return err
		end
		if #rendered == 0 then
			return "Sequence[]"
		end
		return string.format("Sequence[%s]", table.concat(rendered, ", "))
	end,
	Equality = function(node, recur_render)
		local lhs, lhs_err = render_node(node.lhs, recur_render)
		if not lhs then
			return lhs_err
		end
		local rhs, rhs_err = render_node(node.rhs, recur_render)
		if not rhs then
			return rhs_err
		end
		return string.format("(%s) == (%s)", lhs, rhs)
	end,
	Inequality = function(node, recur_render)
		local lhs, lhs_err = render_node(node.lhs, recur_render)
		if not lhs then
			return lhs_err
		end
		local rhs, rhs_err = render_node(node.rhs, recur_render)
		if not rhs then
			return rhs_err
		end
		local op = inequality_ops[node.op] or node.op or "<"
		return string.format("(%s) %s (%s)", lhs, op, rhs)
	end,
	Point2 = function(node, recur_render)
		return render_point({ node.x, node.y }, recur_render)
	end,
	Point3 = function(node, recur_render)
		return render_point({ node.x, node.y, node.z }, recur_render)
	end,
	Parametric2D = function(node, recur_render)
		return render_parametric({ node.x, node.y }, recur_render)
	end,
	Parametric3D = function(node, recur_render)
		return render_parametric({ node.x, node.y, node.z }, recur_render)
	end,
	Polar2D = function(node, recur_render)
		if node.r == nil then
			return "0"
		end
		local rendered, err = render_node(node.r, recur_render)
		if not rendered then
			return err
		end
		return rendered
	end,
}

return M
