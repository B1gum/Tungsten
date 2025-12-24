local evaluator = require("tungsten.core.engine")
local config = require("tungsten.config")
local cmd_utils = require("tungsten.util.commands")
local ast = require("tungsten.core.ast")
local selection = require("tungsten.util.selection")
local parser = require("tungsten.core.parser")

local M = {}

M.TungstenGaussEliminate = {
	description = "GaussEliminate",
	input_handler = function()
		local node, text, err = cmd_utils.parse_selected_latex("matrix")
		if err then
			return nil, nil, err
		end
		if not node then
			return nil, nil, nil
		end
		if node.type ~= "matrix" then
			return nil, nil, "The selected text is not a valid matrix."
		end
		return node, text, nil
	end,
	prepare_args = function(node, _)
		return { ast.create_gauss_eliminate_node(node), config.numeric_mode }
	end,
	task_handler = function(ast_node, numeric_mode, callback)
		evaluator.evaluate_async(ast_node, numeric_mode, callback)
	end,
	separator = " \\rightarrow ",
}

local function linear_independent_result_handler(result)
	if result == nil or result == "" then
		return nil
	end
	local final
	if type(result) == "string" then
		local inner = result:match("^\\text{(.+)}$")
		if inner == "True" or inner == "False" then
			final = inner
		elseif result == "True" or result == "False" then
			final = result
		else
			final = "Undetermined (" .. result .. ")"
		end
	else
		final = "Undetermined (" .. tostring(result) .. ")"
	end
	return final
end

M.TungstenLinearIndependent = {
	description = "LinearIndependent",
	input_handler = function()
		local text = selection.get_visual_selection()
		if not text or text == "" then
			return nil, nil, "No matrix or vectors selected."
		end

		local ok, parsed, err_msg = pcall(parser.parse, text)
		if not ok or not parsed then
			return nil, nil, err_msg or tostring(parsed)
		end

		local node
		if parsed.series and #parsed.series > 1 then
			for i, item in ipairs(parsed.series) do
				if item.type ~= "vector" and item.type ~= "symbolic_vector" and item.type ~= "matrix" then
					return nil, nil, "Item " .. i .. " is not a valid vector or matrix. Parsed as: " .. (item.type or "nil")
				end
			end
			node = ast.create_vector_list_node(parsed.series)
		elseif parsed.series and #parsed.series == 1 then
			node = parsed.series[1]
		else
			return nil, nil, "Selection contains no valid expressions."
		end

		if
			node.type ~= "matrix"
			and node.type ~= "vector_list"
			and node.type ~= "symbolic_vector"
			and node.type ~= "vector"
		then
			return nil, nil, "Selected text is not a valid matrix or list of vectors. Parsed as: " .. node.type
		end
		return node, text, nil
	end,
	prepare_args = function(node, _)
		return { ast.create_linear_independent_test_node(node), false }
	end,
	task_handler = function(test_node, numeric_mode, cb)
		evaluator.evaluate_async(test_node, numeric_mode, function(res, err)
			if err then
				cb(nil, err)
				return
			end
			cb(linear_independent_result_handler(res), nil)
		end)
	end,
}

M.TungstenRank = {
	description = "Rank",
	input_handler = function()
		local node, text, err = cmd_utils.parse_selected_latex("matrix")
		if err then
			return nil, nil, err
		end
		if not node then
			return nil, nil, nil
		end
		if node.type ~= "matrix" then
			return nil, nil, "The selected text is not a valid matrix. Parsed as: " .. node.type
		end
		return node, text, nil
	end,
	prepare_args = function(node, _)
		return { ast.create_rank_node(node), true }
	end,
	task_handler = function(rank_node, numeric_mode, cb)
		evaluator.evaluate_async(rank_node, numeric_mode, cb)
	end,
	separator = " \\rightarrow ",
}

local function simple_matrix_def(name, ast_builder)
	return {
		description = name,
		input_handler = function()
			local node, text, err = cmd_utils.parse_selected_latex("matrix")
			if err then
				return nil, nil, err
			end
			if not node then
				return nil, nil, nil
			end
			if node.type ~= "matrix" then
				return nil, nil, "The selected text is not a valid matrix. Parsed as: " .. (node and node.type or "nil")
			end
			return node, text, nil
		end,
		prepare_args = function(node, _)
			return { ast_builder(node), config.numeric_mode }
		end,
		task_handler = function(a, numeric_mode, cb)
			evaluator.evaluate_async(a, numeric_mode, cb)
		end,
		separator = " \\rightarrow ",
	}
end

M.TungstenEigenvalue = simple_matrix_def("Eigenvalue", ast.create_eigenvalues_node)
M.TungstenEigenvector = simple_matrix_def("Eigenvector", ast.create_eigenvectors_node)
M.TungstenEigensystem = simple_matrix_def("Eigensystem", ast.create_eigensystem_node)

return M
