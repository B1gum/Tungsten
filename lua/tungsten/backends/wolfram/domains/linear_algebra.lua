-- lua/tungsten/backends/wolfram/domains/linear_algebra.lua

local logger = require("tungsten.util.logger")

local function matrix_to_vector_str(node, render)
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
			table.insert(rendered_rows, "{" .. table.concat(rendered_elements_in_row, ", ") .. "}")
		end
		return "{" .. table.concat(rendered_rows, ", ") .. "}"
	end,

	vector = function(node, recur_render)
		local rendered_elements = {}
		for _, element_node in ipairs(node.elements) do
			table.insert(rendered_elements, recur_render(element_node))
		end
		return "{" .. table.concat(rendered_elements, ", ") .. "}"
	end,

	symbolic_vector = function(node, recur_render)
		return recur_render(node.name_expr)
	end,

	determinant = function(node, recur_render)
		local expr_str = recur_render(node.expression)
		if not is_matrix_like(node.expression) then
			return ("Abs[%s]"):format(expr_str)
		end
		return ("Det[%s]"):format(expr_str)
	end,

	transpose = function(node, recur_render)
		return ("Transpose[%s]"):format(recur_render(node.expression))
	end,

	inverse = function(node, recur_render)
		return ("Inverse[%s]"):format(recur_render(node.expression))
	end,

	dot_product = function(node, recur_render)
		local left_str = matrix_to_vector_str(node.left, recur_render)
		local right_str = matrix_to_vector_str(node.right, recur_render)
		return ("Dot[%s, %s]"):format(left_str, right_str)
	end,

	cross_product = function(node, recur_render)
		local left_str = recur_render(node.left)
		local right_str = recur_render(node.right)
		return ("Cross[Flatten[%s], Flatten[%s]]"):format(left_str, right_str)
	end,

	norm = function(node, recur_render)
		local expr_str = recur_render(node.expression)
		if not is_matrix_like(node.expression) then
			return ("Abs[%s]"):format(expr_str)
		end

		if node.p_value then
			local p_val_str = recur_render(node.p_value)
			return ("Norm[%s, %s]"):format(expr_str, p_val_str)
		end

		return ("Norm[%s]"):format(expr_str)
	end,

	matrix_power = function(node, recur_render)
		local base_str = recur_render(node.base)
		local exp_str = recur_render(node.exponent)
		return ("MatrixPower[%s, %s]"):format(base_str, exp_str)
	end,

	identity_matrix = function(node, recur_render)
		local dim_str = recur_render(node.dimension)
		return ("IdentityMatrix[%s]"):format(dim_str)
	end,

	zero_vector_matrix = function(node, recur_render)
		local dim_spec_str = recur_render(node.dimensions)
		return ("ConstantArray[0, %s]"):format(dim_spec_str)
	end,

	gauss_eliminate = function(node, recur_render)
		local matrix_str = recur_render(node.expression)
		return ("RowReduce[%s]"):format(matrix_str)
	end,

	vector_list = function(node, recur_render)
		local rendered_vectors = {}
		for _, vector_node_in_list in ipairs(node.vectors) do
			local vector_str = matrix_to_vector_str(vector_node_in_list, recur_render)
			table.insert(rendered_vectors, vector_str)
		end
		return "{" .. table.concat(rendered_vectors, ", ") .. "}"
	end,

	linear_independent_test = function(node, recur_render)
		local target_ast = node.target
		local rendered_argument_list

		if target_ast.type == "matrix" then
			rendered_argument_list = recur_render(target_ast)
		elseif target_ast.type == "vector_list" then
			local vectors_for_wolfram = {}
			for _, vec_node in ipairs(target_ast.vectors) do
				table.insert(vectors_for_wolfram, recur_render(vec_node))
			end
			rendered_argument_list = "{" .. table.concat(vectors_for_wolfram, ", ") .. "}"
		elseif target_ast.type == "vector" or target_ast.type == "symbolic_vector" then
			rendered_argument_list = "{" .. recur_render(target_ast) .. "}"
		else
			logger.warn("Tungsten: linear_independent_test handler received unexpected AST type: " .. target_ast.type)
			rendered_argument_list = recur_render(target_ast)
		end

		return ('ResourceFunction["LinearlyIndependent"][%s]'):format(rendered_argument_list)
	end,

	rank = function(node, recur_render)
		local matrix_str = recur_render(node.expression)
		return ("MatrixRank[%s]"):format(matrix_str)
	end,

	eigenvalues = function(node, recur_render)
		local matrix_str = recur_render(node.expression)
		return ("Eigenvalues[%s]"):format(matrix_str)
	end,

	eigenvectors = function(node, recur_render)
		local matrix_str = recur_render(node.expression)
		return ("Eigenvectors[%s]"):format(matrix_str)
	end,

	eigensystem = function(node, recur_render)
		local matrix_str = recur_render(node.expression)
		return ("Eigensystem[%s]"):format(matrix_str)
	end,
}

return M
