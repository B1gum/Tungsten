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
  if text == "" then
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

  -- evaluate asynchronously
  evaluator.evaluate_async(ast, config.numeric_mode, function(result)
    if not result or result == "" then
      vim.notify("Tungsten: evaluation failed.", vim.log.levels.ERROR)
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

-------------------------------------------------------------------------------
-- :TungstenParserTestCore  – run the LPeg parser test‑suite shipped in /test
-------------------------------------------------------------------------------
local function tungsten_parser_test_core_command()
  -- absolute path to   …/test/parser/test_core.lua
  local info       = debug.getinfo(1, "S")
  local plugin_dir = info.source:sub(2):match("(.*/)")     -- strip the leading '@'
  vim.cmd("luafile " .. plugin_dir .. "test/parser/test_core.lua")
end

vim.api.nvim_create_user_command(
  "TungstenParserTestCore",
  tungsten_parser_test_core_command,
  { desc = "Run LPeg parser tests" }
)

return {
  tungsten_eval_command          = tungsten_eval_command,
  tungsten_parser_test_core_command = tungsten_parser_test_core_command,
}
