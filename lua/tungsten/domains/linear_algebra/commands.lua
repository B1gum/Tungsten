local selection = require "tungsten.util.selection"
local logger = require "tungsten.util.logger"
local parser    = require "tungsten.core.parser"
local evaluator = require "tungsten.core.engine"
local insert_result_util = require "tungsten.util.insert_result"
local config    = require "tungsten.config"


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

  local ast = require("tungsten.core.ast")
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

vim.api.nvim_create_user_command(
  "TungstenGaussEliminate",
  tungsten_gauss_eliminate_command,
  { range = true, desc = "Perform Gaussian elimination (RowReduce) on the selected matrix" }
)

return {
  tungsten_gauss_eliminate_command = tungsten_gauss_eliminate_command,
}
