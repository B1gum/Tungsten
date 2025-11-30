local M = {}

function M.should_wrap_in_parens(parent_op_data, child_node, op_attributes, is_left_child_of_parent)
	if not parent_op_data then
		return false
	end

	if not child_node or child_node.type ~= "binary" then
		return false
	end

	local child_op_data = op_attributes[child_node.operator]

	if not child_op_data then
		return true
	end

	local child_prec_val = child_op_data.prec
	local parent_prec_val = parent_op_data.prec

	if child_prec_val < parent_prec_val then
		return true
	end

	if child_prec_val > parent_prec_val then
		return false
	end

	local parent_assoc_val = parent_op_data.assoc

	if parent_assoc_val == "N" then
		return true
	end

	if is_left_child_of_parent then
		return parent_assoc_val == "R"
	else
		return parent_assoc_val == "L"
	end
end

function M.map_render(nodes, recur_render)
	local rendered = {}

	if not nodes then
		return rendered
	end

	for _, node in ipairs(nodes) do
		table.insert(rendered, recur_render(node))
	end

	return rendered
end

function M.render_fields(node, field_names, render_fn)
        local rendered = {}

        for index, name in ipairs(field_names) do
                rendered[index] = render_fn(node[name])
        end

        return table.unpack(rendered)
end

return M
