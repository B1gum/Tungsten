--------------------------------------------------------------------------------
-- style.lua
-- Parses curly-brace style specs for plot commands (legend, color, thickness, etc.)
--------------------------------------------------------------------------------

local colors = require("tungsten.plot.colors")
local knownColors = colors.knownColors

local M = {}

-- Parse plot options from a curly-string (e.g., "legend, red--, 3")
-- Returns { hasLegend = bool, directives = { "Directive[...]", ... } }
function M.parse_plot_options(curlyString, numExprs)
  local tokens = {}
  for piece in curlyString:gmatch("[^,]+") do
    local trimmed = piece:gsub("^%s+", ""):gsub("%s+$", "")
    table.insert(tokens, trimmed)
  end

  local hasLegend = false

  local colorFor = {}
  local thickFor = {}
  local styleFor = {}

  local colorIndex, thickIndex, styleIndex = 1, 1, 1

  for _, token in ipairs(tokens) do
    local lowerTok = token:lower()
    if lowerTok == "legend" then
      hasLegend = true
    else
      -- e.g. "red--"
      local colorPart, dashPart = token:match("^(%a+)(%-+)$")
      if colorPart and dashPart then
        -- color
        if knownColors[colorPart:lower()] then
          if colorIndex <= numExprs then
            colorFor[colorIndex] = colorPart
            colorIndex = colorIndex + 1
          end
        end
        -- style
        if styleIndex <= numExprs then
          styleFor[styleIndex] = (dashPart == "--") and "Dashed" or "Solid"
          styleIndex = styleIndex + 1
        end
      else
        -- pure color
        if knownColors[lowerTok] then
          if colorIndex <= numExprs then
            colorFor[colorIndex] = lowerTok
            colorIndex = colorIndex + 1
          end
        -- style only ("--" or "-")
        elseif token:match("^%-+$") then
          if styleIndex <= numExprs then
            styleFor[styleIndex] = (token == "--") and "Dashed" or "Solid"
            styleIndex = styleIndex + 1
          end
        -- thickness
        elseif tonumber(token) then
          if thickIndex <= numExprs then
            thickFor[thickIndex] = tonumber(token) * 0.005
            thickIndex = thickIndex + 1
          end
        end
      end
    end
  end

  -- Assign default colors
  for i = 1, numExprs do
    if not colorFor[i] then
      colorFor[i] = colors.get_next_default_color()
    else
      -- If user typed a recognized color name
      local colorName = colorFor[i]:lower()
      if knownColors[colorName] then
        colorFor[i] = colorName:sub(1,1):upper() .. colorName:sub(2)
      else
        -- If user typed e.g. "purpleish", not recognized
        colorFor[i] = colors.get_next_default_color()
      end
    end
  end

  -- Build final directives
  local directives = {}
  for i = 1, numExprs do
    local parts = {}
    if thickFor[i] then
      table.insert(parts, string.format("Thickness[%f]", thickFor[i]))
    end
    if colorFor[i] then
      table.insert(parts, colorFor[i])
    end
    if styleFor[i] then
      table.insert(parts, styleFor[i])
    end

    if #parts > 0 then
      table.insert(directives, "Directive[" .. table.concat(parts, ", ") .. "]")
    else
      table.insert(directives, "Automatic")
    end
  end

  return {
    hasLegend = hasLegend,
    directives = directives,
  }
end

return M

