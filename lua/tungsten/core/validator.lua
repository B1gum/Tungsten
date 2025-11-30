local error_handler = require("tungsten.util.error_handler")
local helpers = require("tungsten.domains.plotting.helpers")

local M = {}

local function is_theta(node)
	return node and (node.type == "variable" or node.type == "greek") and node.name == "theta"
end

local function tuple_part_position(meta, idx)
	if not meta then
		return nil
	end
	local base_offset = meta.base_offset or 1
	local part = meta.parts and meta.parts[idx]
	if not part then
		return base_offset
	end
	local trim_leading = part.trim_leading or 0
	return base_offset + part.start_pos - 1 + trim_leading
end

local function validate_tuple_node(node, opts)
	local meta = node._tuple_meta
	if not meta then
		return true
	end

	local elements = meta.elements or {}
	local form = (meta.opts and meta.opts.form) or (opts and opts.form)
	local mode = (meta.opts and meta.opts.mode) or (opts and opts.mode)
	local input = meta.input or (node._source and node._source.input) or ""
	local count = #elements

	if count == 2 then
		local second = elements[2]
		if form ~= "polar" and is_theta(second) then
			local global_pos = tuple_part_position(meta, 2)
			local msg = "Coordinate system mismatch: theta can unly be used with polar coordinates at "
				.. error_handler.format_line_col(input, global_pos)
			return nil, msg, global_pos
		end
	end

	if mode == "advanced" and form == "parametric" then
		local elem_params = {}
		local union_set = {}
		for i, e in ipairs(elements) do
			local params = helpers.extract_param_names(e)
			elem_params[i] = params
			for _, p in ipairs(params) do
				union_set[p] = true
			end
		end

		local union = {}
		for p in pairs(union_set) do
			table.insert(union, p)
		end
		table.sort(union)

		local function elements_share_union()
			for _, params in ipairs(elem_params) do
				if #params ~= #union then
					return false
				end
				for _, n in ipairs(params) do
					if not union_set[n] then
						return false
					end
				end
			end
			return true
		end

		if count == 3 then
			if not (#union == 2 and union[1] == "u" and union[2] == "v" and elements_share_union()) then
				local global_pos = tuple_part_position(meta, 1)
				local msg = "Parametric 3D tuples must use parameters u and v at "
					.. error_handler.format_line_col(input, global_pos)
				return nil, msg, global_pos
			end
		end
	elseif form == "polar" then
		if count ~= 2 then
			local pos_idx = count >= 3 and 3 or 1
			local global_pos = tuple_part_position(meta, pos_idx)
			local msg = "Polar typles support only 2D at " .. error_handler.format_line_col(input, global_pos)
			return nil, msg, global_pos
		end

		local theta = elements[2]
		if not is_theta(theta) then
			local global_pos = tuple_part_position(meta, 2)
			local msg = "Polar tuples must have theta as second element at "
				.. error_handler.format_line_col(input, global_pos)
			return nil, msg, global_pos
		end

		if not helpers.is_theta_function(elements[1]) then
			local global_pos = tuple_part_position(meta, 1)
			local msg = "Polar tuples must define r as a function of θ at "
				.. error_handler.format_line_col(input, global_pos)
			return nil, msg, global_pos
		end
	end

	return true
end

local function node_dimension(n)
	if type(n) ~= "table" then
		return nil
	end
	if n.type == "Point2" or n.type == "Parametric2D" or n.type == "Polar2D" then
		return 2
	elseif n.type == "Point3" or n.type == "Parametric3D" then
		return 3
	end
	return nil
end

local function validate_dimensions(series)
	local global_point_dim
	for _, node in ipairs(series) do
		local targets
		if node and node.type == "Sequence" then
			targets = node.nodes or {}
		else
			targets = { node }
		end

		for _, child in ipairs(targets) do
			local dim = node_dimension(child)
			if dim then
				if global_point_dim and global_point_dim ~= dim then
					local source = child._source or {}
					local input = source.input or ""
					local pos = source.start_pos or 1
					local msg = "Cannot mix 2D and 3D points in the same sequence or series at "
						.. error_handler.format_line_col(input, pos)
					return nil, msg, pos
				end
				global_point_dim = global_point_dim or dim
			end
		end
	end
	return true
end

function M.validate(ast_root, opts)
	if not ast_root or not ast_root.series then
		return nil, "Invalid AST"
	end

	for _, node in ipairs(ast_root.series) do
		if node and node._tuple_meta then
			local ok, err, pos = validate_tuple_node(node, opts)
			if not ok then
				return nil, err, pos
			end
		end
		if node and node.type == "Sequence" then
			for _, child in ipairs(node.nodes or {}) do
				if child and child._tuple_meta then
					local ok, err, pos = validate_tuple_node(child, opts)
					if not ok then
						return nil, err, pos
					end
				end
			end
		end
	end

	local dim_ok, dim_err, dim_pos = validate_dimensions(ast_root.series)
	if not dim_ok then
		return nil, dim_err, dim_pos
	end

	return true
end

return M
