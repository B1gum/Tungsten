-- lua/tungsten/backends/python/domains/linear_algebra.lua
-- SymPy handlers for linear algebra operations

local logger = require("tungsten.util.logger")

local function matrix_to_vector_str(node, render)
	if type(node) == "table" and node.type == "matrix" then
		if #node.rows == 0 then
			return "Matrix([])"
		end

		if #node.rows == 1 then
			local elems = {}
			for _, el in ipairs(node.rows[1]) do
				elems[#elems + 1] = render(el)
			end
			return "Matrix([" .. table.concat(elems, ", ") .. "])"
		elseif node.rows[1] and #node.rows[1] == 1 then
			local elems = {}
			for _, row in ipairs(node.rows) do
				elems[#elems + 1] = render(row[1])
			end
			return "Matrix([" .. table.concat(elems, ", ") .. "])"
		end
	end
	return render(node)
end

local function is_matrix_like(node)
	if type(node) ~= "table" then
		return false
	end
	if
		node.type == "matrix"
		or node.type == "vector"
		or node.type == "symbolic_vector"
		or node.type == "cross_product"
	then
		return true
	end
	if type(node.type) == "string" and node.type:match("_placeholder$") then
		return true
	end
	if (node.type == "variable" or node.type == "symbol" or node.type == "greek") and type(node.name) == "string" then
		return node.name:match("^[A-Z]") ~= nil
	end
	if node.type == "function_call" then
		return is_matrix_like(node.name_node)
	end
	return false
end

local M = {}

M.matrix_to_vector_str = matrix_to_vector_str

M.handlers = {
	matrix = function(node, recur_render)
		local rendered_rows = {}
		for _, row_elements in ipairs(node.rows) do
			local rendered_elements_in_row = {}
			for _, element_node in ipairs(row_elements) do
				table.insert(rendered_elements_in_row, recur_render(element_node))
			end
			table.insert(rendered_rows, "[" .. table.concat(rendered_elements_in_row, ", ") .. "]")
		end
		return "Matrix([" .. table.concat(rendered_rows, ", ") .. "])"
	end,

	vector = function(node, recur_render)
		local rendered_elements = {}
		for _, element_node in ipairs(node.elements) do
			table.insert(rendered_elements, recur_render(element_node))
		end
		return "Matrix([" .. table.concat(rendered_elements, ", ") .. "])"
	end,

	symbolic_vector = function(node, recur_render)
		return recur_render(node.name_expr)
	end,

	determinant = function(node, recur_render)
		local expr_str = recur_render(node.expression)
		if not is_matrix_like(node.expression) then
			return ("sp.Abs(%s)"):format(expr_str)
		end
		return ("sp.det(%s)"):format(expr_str)
	end,

	transpose = function(node, recur_render)
		return ("sp.transpose(%s)"):format(recur_render(node.expression))
	end,

	inverse = function(node, recur_render)
		return ("sp.Matrix(%s).inv()"):format(recur_render(node.expression))
	end,

	dot_product = function(node, recur_render)
		local left_str = matrix_to_vector_str(node.left, recur_render)
		local right_str = matrix_to_vector_str(node.right, recur_render)
		return ("(%s).dot(%s)"):format(left_str, right_str)
	end,

	cross_product = function(node, recur_render)
		local left_str = matrix_to_vector_str(node.left, recur_render)
		local right_str = matrix_to_vector_str(node.right, recur_render)
		return ("(%s).cross(%s)"):format(left_str, right_str)
	end,

	norm = function(node, recur_render)
		local expr_str = recur_render(node.expression)
		if not is_matrix_like(node.expression) then
			return ("sp.Abs(%s)"):format(expr_str)
		end

		if node.p_value then
			local p_val_str = recur_render(node.p_value)
			return ("(%s).norm(%s)"):format(expr_str, p_val_str)
		end

		return ("(%s).norm()"):format(expr_str)
	end,

	matrix_power = function(node, recur_render)
		local base_str = recur_render(node.base)
		local exp_str = recur_render(node.exponent)
		return ("sp.Matrix(%s) ** %s"):format(base_str, exp_str)
	end,

	identity_matrix = function(node, recur_render)
		local dim_str = recur_render(node.dimension)
		return ("sp.eye(%s)"):format(dim_str)
	end,

	zero_vector_matrix = function(node, recur_render)
		local dim_spec_str = recur_render(node.dimensions)
		return ("sp.zeros(%s)"):format(dim_spec_str)
	end,

	gauss_eliminate = function(node, recur_render)
		local matrix_str = recur_render(node.expression)
		return ("sp.Matrix(%s).rref()[1]"):format(matrix_str)
	end,

	vector_list = function(node, recur_render)
		local rendered_vectors = {}
		for _, vector_node_in_list in ipairs(node.vectors) do
			local vector_str = matrix_to_vector_str(vector_node_in_list, recur_render)
			table.insert(rendered_vectors, vector_str)
		end
		return "[" .. table.concat(rendered_vectors, ", ") .. "]"
	end,

	linear_independent_test = function(node, recur_render)
		local target_ast = node.target
		local rendered_argument_list

		if target_ast.type == "matrix" then
			rendered_argument_list = recur_render(target_ast)
		elseif target_ast.type == "vector_list" then
			local vectors_for_python = {}
			for _, vec_node in ipairs(target_ast.vectors) do
				if vec_node.type == "matrix" then
					local elements = {}
					if #vec_node.rows == 1 then
						for _, el_node in ipairs(vec_node.rows[1]) do
							table.insert(elements, recur_render(el_node))
						end
						table.insert(vectors_for_python, "Matrix([" .. table.concat(elements, ", ") .. "])")
					elseif #vec_node.rows > 0 and #vec_node.rows[1] and #vec_node.rows[1] == 1 then
						for _, row_array in ipairs(vec_node.rows) do
							table.insert(elements, recur_render(row_array[1]))
						end
						table.insert(vectors_for_python, "Matrix([" .. table.concat(elements, ", ") .. "])")
					else
						table.insert(vectors_for_python, recur_render(vec_node))
					end
				else
					table.insert(vectors_for_python, recur_render(vec_node))
				end
			end
			rendered_argument_list = "[" .. table.concat(vectors_for_python, ", ") .. "]"
		elseif target_ast.type == "vector" or target_ast.type == "symbolic_vector" then
			rendered_argument_list = "[" .. recur_render(target_ast) .. "]"
		else
			logger.warn("Tungsten: linear_independent_test handler received unexpected AST type: " .. target_ast.type)
			rendered_argument_list = recur_render(target_ast)
		end

		return ("sp.Matrix.hstack(%s).rank() == len(%s)"):format(rendered_argument_list, rendered_argument_list)
	end,

	rank = function(node, recur_render)
		local matrix_str = recur_render(node.expression)
		return ("sp.Matrix(%s).rank()"):format(matrix_str)
	end,

	eigenvalues = function(node, recur_render)
		local matrix_str = recur_render(node.expression)
		return ("sp.Matrix(%s).eigenvals()"):format(matrix_str)
	end,

	eigenvectors = function(node, recur_render)
		local matrix_str = recur_render(node.expression)
		return ("sp.Matrix(%s).eigenvects()"):format(matrix_str)
	end,

	eigensystem = function(node, recur_render)
		local matrix_str = recur_render(node.expression)
		return ("sp.Matrix(%s).eigenvects()"):format(matrix_str)
	end,
}

return M
