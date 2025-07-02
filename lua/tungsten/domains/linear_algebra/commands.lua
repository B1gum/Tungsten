local selection = require "tungsten.util.selection"
local error_handler = require "tungsten.util.error_handler"
local parser    = require "tungsten.core.parser"
local evaluator = require "tungsten.core.engine"
local insert_result_util = require "tungsten.util.insert_result"
local config    = require "tungsten.config"
local ast = require("tungsten.core.ast")
local cmd_utils = require "tungsten.util.commands"


local function tungsten_gauss_eliminate_command(_)
  local matrix_ast, _, err = cmd_utils.parse_selected_latex("matrix")
  if err then
    error_handler.notify_error("GaussEliminate", err)
    return
  end
  if not matrix_ast then return end

  if matrix_ast.type ~= "matrix" then
    error_handler.notify_error("GaussEliminate", "The selected text is not a valid matrix.")
    return
  end

  local gauss_eliminate_ast_node = ast.create_gauss_eliminate_node(matrix_ast)

  local use_numeric_mode = config.numeric_mode

  evaluator.evaluate_async(gauss_eliminate_ast_node, use_numeric_mode, function(result, err)
    if err then
      error_handler.notify_error("GaussEliminate", "Error during evaluation: " .. tostring(err))
      return
    end
    if result == nil or result == "" then
      error_handler.notify_error("GaussEliminate", "No result from evaluation.")
      return
    end
    insert_result_util.insert_result(result, " \\rightarrow ")
  end)
end

local function tungsten_linear_independent_command(_)
  local parsed_ast, _, err = cmd_utils.parse_selected_latex("matrix or list of vectors")
  if err then
    error_handler.notify_error("LinearIndependent", err)
    return
  end
  if not parsed_ast then return end

  if parsed_ast.type ~= "matrix" and parsed_ast.type ~= "vector_list" and parsed_ast.type ~= "symbolic_vector" and parsed_ast.type ~= "vector" then
    error_handler.notify_error("LinearIndependent", "Selected text is not a valid matrix or list of vectors. Parsed as: " .. parsed_ast.type)
    return
  end

  local linear_independent_node = ast.create_linear_independent_test_node(parsed_ast)

  evaluator.evaluate_async(linear_independent_node, false, function(result, err)
    if err then
      error_handler.notify_error("LinearIndependent", "Error during evaluation: " .. tostring(err))
      return
    end
    if result == nil or result == "" then
      error_handler.notify_error("LinearIndependent", "No result from evaluation (True/False expected).")
      return
    end

    local final_display_result
    if type(result) == "string" then
      local inner_text = result:match("^\\text{(.+)}$")
      if inner_text == "True" or inner_text == "False" then
        final_display_result = inner_text
      else
        if result == "True" or result == "False" then
          final_display_result = result
        else
          final_display_result = "Undetermined (" .. result .. ")"
        end
      end
    else
      final_display_result = "Undetermined (" .. tostring(result) .. ")"
    end

    insert_result_util.insert_result(final_display_result)
  end)
end

local function tungsten_rank_command(_)
  local matrix_ast_node, _, err = cmd_utils.parse_selected_latex("matrix")
  if err then
    error_handler.notify_error("Rank", err)
    return
  end
  if not matrix_ast_node then return end

  if matrix_ast_node.type ~= "matrix" then
    error_handler.notify_error("Rank", "The selected text is not a valid matrix. Parsed as: " .. matrix_ast_node.type)
    return
  end

  local rank_ast_node = ast.create_rank_node(matrix_ast_node)
  local use_numeric_mode = true

  evaluator.evaluate_async(rank_ast_node, use_numeric_mode, function(result, err)
    if err then
      error_handler.notify_error("Rank", "Error during evaluation: " .. tostring(err))
      return
    end
    if result == nil or result == "" then
      error_handler.notify_error("Rank", "No result from evaluation (expected a numner).")
      return
    end
    insert_result_util.insert_result(result, " \\rightarrow ")
  end)
end

local function tungsten_eigenvalue_command(_)
    local matrix_ast_node, _, err = cmd_utils.parse_selected_latex("matrix")
    if err then
      error_handler.notify_error("Eigenvalue", err)
      return
    end
    if not matrix_ast_node then return end

    if matrix_ast_node.type ~= "matrix" then
        error_handler.notify_error("Eigenvalue", "The selected text is not a valid matrix. Parsed as: " .. (matrix_ast_node and matrix_ast_node.type or "nil"))
        return
    end

    local eigenvalues_ast_node = ast.create_eigenvalues_node(matrix_ast_node)
    local use_numeric_mode = config.numeric_mode

    evaluator.evaluate_async(eigenvalues_ast_node, use_numeric_mode, function(result, err)
        if err then
            error_handler.notify_error("Eigenvalue", "Error during evaluation: " ..tostring(err))
            return
        end
        if result == nil or result == "" then
            error_handler.notify_error("Eigenvalue", "No result from evaluation.")
            return
        end
        insert_result_util.insert_result(result, " \\rightarrow ")
    end)
end

local function tungsten_eigenvector_command(_)
    local matrix_ast_node, _, err = cmd_utils.parse_selected_latex("matrix")
    if err then
      error_handler.notify_error("Eigenvector", err)
      return
    end
    if not matrix_ast_node then return end

    if matrix_ast_node.type ~= "matrix" then
        error_handler.notify_error("Eigenvector", "The selected text is not a valid matrix. Parsed as: " .. (matrix_ast_node and matrix_ast_node.type or "Nil"))
        return
    end

    local eigenvectors_ast_node = ast.create_eigenvectors_node(matrix_ast_node)
    local use_numeric_mode = config.numeric_mode

    evaluator.evaluate_async(eigenvectors_ast_node, use_numeric_mode, function(result, err)
        if err then
            error_handler.notify_error("Eigenvector", "Error during evaluation: " .. tostring(err))
            return
        end
        if result == nil or result == "" then
            error_handler.notify_error("Eigenvector", "No result from evaluation.")
            return
        end
        insert_result_util.insert_result(result, " \\rightarrow ")
    end)
end

local function tungsten_eigensystem_command(_)
    local matrix_ast_node, _, err = cmd_utils.parse_selected_latex("matrix")
    if err then
      error_handler.notify_error("Eigensysem", err)
      return
    end
    if not matrix_ast_node then return end

    if matrix_ast_node.type ~= "matrix" then
        error_handler.notify_error("Eigensystem", "The selected text is not a valid matrix. Parsed as: " .. (matrix_ast_node and matrix_ast_node.type or "Nil"))
        return
    end

    local eigensystem_ast_node = ast.create_eigensystem_node(matrix_ast_node)
    local use_numeric_mode = config.numeric_mode

    evaluator.evaluate_async(eigensystem_ast_node, use_numeric_mode, function(result, err)
        if err then
            error_handler.notify_error("Eigensystem", "Error during evaluation: " .. tostring(err))
            return
        end
        if result == nil or result == "" then
            error_handler.notify_error("Eigensystem", "No result from evaluation.")
            return
        end
        insert_result_util.insert_result(result, " \\rightarrow ")
    end)
end

vim.api.nvim_create_user_command(
  "TungstenGaussEliminate",
  tungsten_gauss_eliminate_command,
  { range = true, desc = "Perform Gaussian elimination (RowReduce) on the selected matrix" }
)

vim.api.nvim_create_user_command(
  "TungstenLinearIndependent",
  tungsten_linear_independent_command,
  { range = true, desc = "Test if selected vectors/matrix rows or columns are linearly independent" }
)

vim.api.nvim_create_user_command(
  "TungstenRank",
  tungsten_rank_command,
  { range = true, desc = "Calculate the rank of the selected LaTeX matrix" }
)

vim.api.nvim_create_user_command(
  "TungstenEigenvalue",
  tungsten_eigenvalue_command,
  { range = true, desc = "Calculate the eigenvalues of the selected LaTeX matrix" }
)

vim.api.nvim_create_user_command(
  "TungstenEigenvector",
  tungsten_eigenvector_command,
  { range = true, desc = "Calculate the eigenvectors of the selected LaTeX matrix" }
)

vim.api.nvim_create_user_command(
  "TungstenEigensystem",
  tungsten_eigensystem_command,
  { range = true, desc = "Calculate the eigensystem (eigenvalues and eigenvectors) of the selected LaTeX matrix" }
)

return {
  tungsten_gauss_eliminate_command = tungsten_gauss_eliminate_command,
  tungsten_linear_independent_command = tungsten_linear_independent_command,
  tungsten_rank_command = tungsten_rank_command,
  tungsten_eigenvalue_command = tungsten_eigenvalue_command,
  tungsten_eigenvector_command = tungsten_eigenvector_command,
  tungsten_eigensystem_command = tungsten_eigensystem_command,
}
