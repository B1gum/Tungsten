-- tungsten/util/commands.lua
local M = {}

local selection = require('tungsten.util.selection')
local parser    = require('tungsten.core.parser')
local logger    = require('tungsten.util.logger')

function M.parse_selected_latex(expected_desc)
  local text = selection.get_visual_selection()
  if not text or text == "" then
    logger.notify("Tungsten: No " .. expected_desc .. " selected.",
                  logger.levels.ERROR, {title = "Tungsten Error"})
    return nil
  end

  local ok, ast = pcall(parser.parse, text)
  if not ok or not ast then
    logger.notify("Tungsten: Parse error for selected " .. expected_desc ..
                  " – " .. tostring(ast), logger.levels.ERROR,
                  {title = "Tungsten Error"})
    return nil
  end

  return ast, text
end

return M
