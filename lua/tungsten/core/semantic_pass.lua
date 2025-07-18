local ast = require("tungsten.core.ast")

local M = {}

local function is_matrix_or_vector(node)
	if type(node) ~= "table" then
		return false
	end
	if node.type == "matrix" or node.type == "vector" or node.type == "symbolic_vector" then
		return true
	end
	if node.type == "subscript" and node.base then
		return is_matrix_or_vector(node.base)
	end
	if node.type == "unary" and node.value then
		return is_matrix_or_vector(node.value)
	end
	if node.type == "superscript" and node.base then
		return is_matrix_or_vector(node.base)
	end
	return false
end

local function walk(node)
	if type(node) ~= "table" then
		return node
	end

	for k, v in pairs(node) do
		if type(v) == "table" then
			if v.type then
				node[k] = walk(v)
			else
				for i, elem in ipairs(v) do
					if type(elem) == "table" then
						v[i] = walk(elem)
					end
				end
			end
		end
	end

	if node.type == "superscript" then
		local base = node.base
		local exp = node.exponent
		if is_matrix_or_vector(base) then
			if exp and exp.type == "variable" and exp.name == "T" then
				return ast.create_transpose_node(base)
			end
			if exp and exp.type == "intercal_command" then
				return ast.create_transpose_node(base)
			end
		end

		local base_can_be_inverted = base
			and (base.type == "matrix" or base.type == "symbolic_vector" or base.type == "vector")
		if base_can_be_inverted and exp then
			if exp.type == "number" and exp.value == -1 then
				return ast.create_inverse_node(base)
			end
			if
				exp.type == "unary"
				and exp.operator == "-"
				and exp.value
				and exp.value.type == "number"
				and exp.value.value == 1
			then
				return ast.create_inverse_node(base)
			end
		end
	end

	return node
end

function M.apply(ast_root)
	return walk(ast_root)
end

return M
