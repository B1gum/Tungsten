-- core/comands.lua
-- Defines core user-facing Neovim commands
-------------------------------------------------------------------------------

local parser    = require("tungsten.core.parser")
local evaluator = require("tungsten.core.engine")
local selection = require("tungsten.util.selection")
local insert    = require("tungsten.util.insert_result")
local config    = require("tungsten.config")
local logger    = require("tungsten.util.logger")

local function tungsten_eval_command(_)
  local text = selection.get_visual_selection()
  if text == "" or text == nil then
    logger.notify("Tungsten: No text selected.", logger.levels.ERROR)
    return
  end

  local ok, ast_or_err = pcall(parser.parse, text)
  if not ok or not ast_or_err then
    logger.notify("Tungsten: parse error – " .. tostring(ast_or_err), logger.levels.ERROR)
    return
  end
  local ast = ast_or_err

  local use_numeric_mode = config.numeric_mode

  evaluator.evaluate_async(ast, use_numeric_mode, function(result)
    if result == nil or result == "" then
      return
    end
    insert.insert_result(result)
  end)
end


vim.api.nvim_create_user_command(
  "TungstenEvaluate",
  tungsten_eval_command,
  { range = true, desc = "Evaluate selected LaTeX and insert the result" }
)

vim.api.nvim_create_user_command(
  "TungstenClearCache",
  function()
    evaluator.clear_cache()
  end,
  { desc = "Clear the Tungsten evaluation cache" }
)

vim.api.nvim_create_user_command(
  "TungstenViewActiveJobs",
  function()
    evaluator.view_active_jobs()
  end,
  { desc = "View active Tungsten evaluation jobs" }
)


return {
  tungsten_eval_command = tungsten_eval_command,
}
