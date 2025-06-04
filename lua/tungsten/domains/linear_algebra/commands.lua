local selection = require "tungsten.util.selection"
local logger = require "tungsten.util.logger"
local parser    = require "tungsten.core.parser"
local evaluator = require "tungsten.core.engine"
local insert_result_util = require "tungsten.util.insert_result"
local config    = require "tungsten.config"
local ast = require("tungsten.core.ast")


local function tungsten_gauss_eliminate_command(_)
  local visual_selection_text = selection.get_visual_selection()
  if visual_selection_text == "" or visual_selection_text == nil then
    logger.notify("TungstenGaussEliminate: No matrix selected.", logger.levels.ERROR, { title = "Tungsten Error" })
    return
  end

  local parse_ok, matrix_ast = pcall(parser.parse, visual_selection_text)
  if not parse_ok or not matrix_ast then
    logger.notify("TungstenGaussEliminate: Parse error for selected matrix – " .. tostring(matrix_ast), logger.levels.ERROR, { title = "Tungsten Error" })
    return
  end

  if matrix_ast.type ~= "matrix" then
     logger.notify("TungstenGaussEliminate: The selected text is not a valid matrix.", logger.levels.ERROR, { title = "Tungsten Error" })
    return
  end

  local gauss_eliminate_ast_node = ast.create_gauss_eliminate_node(matrix_ast)

  local use_numeric_mode = config.numeric_mode

  evaluator.evaluate_async(gauss_eliminate_ast_node, use_numeric_mode, function(result, err)
    if err then
      logger.notify("TungstenGaussEliminate: Error during evaluation: " .. tostring(err), logger.levels.ERROR, { title = "Tungsten Error" })
      return
    end
    if result == nil or result == "" then
      logger.notify("TungstenGaussEliminate: No result from evaluation.", logger.levels.WARN, { title = "Tungsten Warning" })
      return
    end
    insert_result_util.insert_result(result)
  end)
end

local function tungsten_linear_independent_command(_)
  local visual_selection_text = selection.get_visual_selection()
  if visual_selection_text == "" or visual_selection_text == nil then
    logger.notify("TungstenLinearIndependent: No text selected.", logger.levels.ERROR, { title = "Tungsten Error" })
    return
  end

  local parsed_ast
  local ok, ast_node = pcall(parser.parse, visual_selection_text)

  if not ok or not ast_node then
    logger.notify("TungstenLinearIndependent: Parse error – " .. tostring(ast_node), logger.levels.ERROR, { title = "Tungsten Error" })
    return
  end

  if ast_node.type ~= "matrix" and ast_node.type ~= "vector_list" and ast_node.type ~= "symbolic_vector" and ast_node.type ~= "vector" then
     logger.notify("TungstenLinearIndependent: Selected text is not a valid matrix or list of vectors. Parsed as: " .. ast_node.type, logger.levels.ERROR, { title = "Tungsten Error" })
    return
  end

  parsed_ast = ast_node

  local linear_independent_node = ast.create_linear_independent_test_node(parsed_ast)

  evaluator.evaluate_async(linear_independent_node, false, function(result, err)
    if err then
      logger.notify("TungstenLinearIndependent: Error during evaluation: " .. tostring(err), logger.levels.ERROR, { title = "Tungsten Error" })
      return
    end
    if result == nil or result == "" then
      logger.notify("TungstenLinearIndependent: No result from evaluation (True/False expected).", logger.levels.WARN, { title = "Tungsten Warning" })
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

return {
  tungsten_gauss_eliminate_command = tungsten_gauss_eliminate_command,
  tungsten_linear_independent_command = tungsten_linear_independent_command,
}
