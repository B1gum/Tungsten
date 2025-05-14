-- core/comands.lua
-- Defines core user-facing Neovim commands
-------------------------------------------------------------------------------

local parser    = require("tungsten.core.parser")
local evaluator = require("tungsten.core.engine")
local selection = require("tungsten.util.selection")
local insert    = require("tungsten.util.insert_result")
local config    = require("tungsten.config")

-------------------------------------------------------------------------------
-- :TungstenEval  – evaluate visually‑selected LaTeX math and insert the result
-------------------------------------------------------------------------------
local function tungsten_eval_command(_)
  local text = selection.get_visual_selection()
  if text == "" or text == nil then
    vim.notify("Tungsten: No text selected.", vim.log.levels.ERROR)
    return
  end

  -- parse → AST
  local ok, ast_or_err = pcall(parser.parse, text)
  if not ok or not ast_or_err then
    vim.notify("Tungsten: parse error – " .. tostring(ast_or_err), vim.log.levels.ERROR)
    return
  end
  local ast = ast_or_err

  local use_numeric_mode = config.numeric_mode

  -- evaluate asynchronously
  evaluator.evaluate_async(ast, use_numeric_mode, function(result)
    if result == nil or result == "" then
      return
    end
    insert.insert_result(result)
  end)
end


vim.api.nvim_create_user_command(
  "TungstenEval",
  tungsten_eval_command,
  { range = true, desc = "Evaluate selected LaTeX and insert the result" }
)

-- Example command to clear the cache
vim.api.nvim_create_user_command(
  "TungstenClearCache",
  function()
    evaluator.clear_cache()
  end,
  { desc = "Clear the Tungsten evaluation cache" }
)

-- Example command to view active jobs
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
