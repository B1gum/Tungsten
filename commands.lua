-- commands.lua
-- Module for defining commands
------------------------------------------

local parser    = require("tungsten.parser.LPeg_parser.grammar")
local evaluator = require("tungsten.evaluate_async")
local selection = require("tungsten.utils.selection")
local insert    = require("tungsten.utils.insert_result")
local config    = require("tungsten.config")

local function tungsten_eval_command(opts)
  -- Retrieve visually selected text
  local text = selection.get_visual_selection()
  if text == "" then
    vim.notify("Tungsten: No text selected.", vim.log.levels.ERROR)
    return
  end

  -- Parse the expression into an AST.
  local success, ast_or_err = pcall(parser.parse_expr, text)
  if not success or not ast_or_err then
    vim.notify("Tungsten: Parse error - " .. tostring(ast_or_err), vim.log.levels.ERROR)
    return
  end
  local ast = ast_or_err

  -- Evaluate the AST asynchronously.
  evaluator.evaluate_async(ast, config.numeric_mode, function(result)
    if not result or result == "" then
      vim.notify("Tungsten: Evaluation failed or returned no result.", vim.log.levels.ERROR)
      return
    end

    -- Insert the result inline
    insert.insert_result(result)
    vim.notify("Tungsten: Evaluation completed successfully.", vim.log.levels.INFO)
  end)
end

vim.api.nvim_create_user_command("TungstenEval", tungsten_eval_command, {
  range = true,
  desc = "Evaluate visually selected LaTeX math and insert result inline",
})

local function tungsten_parser_test_core_command(opts)
  -- Get the absolute directory of this commands.lua file.
  local info = debug.getinfo(1, "S")
  local plugin_dir = info.source:sub(2):match("(.*/)")  -- removes the "@" at the beginning
  local test_file = plugin_dir .. "test/parser/test_core.lua"
  vim.cmd("luafile " .. test_file)
end

vim.api.nvim_create_user_command("TungstenParserTestCore", tungsten_parser_test_core_command, {
  desc = "Run LPeg parser tests from the test file",
})



return {
  tungsten_eval_command = tungsten_eval_command,
  tungsten_parser_test_core_command = tungsten_parser_test_core_command,
}

