-- tungsten/util/commands.lua
local M = {}

local selection = require('tungsten.util.selection')
local parser    = require('tungsten.core.parser')

function M.parse_selected_latex(expected_desc)
  local text = selection.get_visual_selection()
  if not text or text == "" then
    return nil, nil, "No " .. expected_desc .. " selected."
  end

  local ok, ast = pcall(parser.parse, text)
  if not ok or not ast then
    return nil, nil, "Parse error for selected " .. expected_desc .. " – " .. tostring(ast)
  end

  return ast, text, nil
end

return M
